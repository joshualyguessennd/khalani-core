use std::fmt::Debug;
use std::{collections::HashMap, sync::Arc};

use async_trait::async_trait;
use eyre::{Report, Result};
use futures_util::future::select_all;
use tokio::task::JoinHandle;
use tracing::instrument::Instrumented;
use tracing::{info_span, Instrument};

use abacus_core::db::DB;
use abacus_core::InboxValidatorManager;

use crate::{
    cancel_task,
    metrics::CoreMetrics,
    settings::{IndexSettings, Settings},
    AgentSettings, CachingInbox, CachingInterchainGasPaymaster, CachingOutbox,
};

/// Contracts relating to an inbox chain
#[derive(Clone, Debug)]
pub struct InboxContracts {
    /// A boxed Inbox
    pub inbox: CachingInbox,
    /// A boxed InboxValidatorManager
    pub validator_manager: Arc<dyn InboxValidatorManager>,
}

/// Properties shared across all abacus agents
#[derive(Debug)]
pub struct AbacusAgentCore {
    /// A boxed Outbox
    pub outbox: CachingOutbox,
    /// A boxed InterchainGasPaymaster
    pub interchain_gas_paymaster: Option<CachingInterchainGasPaymaster>,
    /// A map of Inbox contracts by name
    pub inboxes: HashMap<String, InboxContracts>,
    /// A persistent KV Store (currently implemented as rocksdb)
    pub db: DB,
    /// Prometheus metrics
    pub metrics: Arc<CoreMetrics>,
    /// The height at which to start indexing the Outbox
    pub indexer: IndexSettings,
    /// Settings this agent was created with
    pub settings: Settings,
}

/// Settings of an agent.
pub trait NewFromAgentSettings: AsRef<AgentSettings> + Sized {
    /// The error type returned by new on failures to parse.
    type Error: Into<Report>;

    /// Create a new instance of these settings by reading the configs and env
    /// vars.
    fn new() -> std::result::Result<Self, Self::Error>;
}

/// A fundamental agent which does not make any assumptions about the tools
/// which are used.
#[async_trait]
pub trait BaseAgent: Send + Sync + Debug {
    /// The agent's name
    const AGENT_NAME: &'static str;

    /// The settings object for this agent
    type Settings: NewFromAgentSettings;

    /// Instantiate the agent from the standard settings object
    async fn from_settings(settings: Self::Settings, metrics: Arc<CoreMetrics>) -> Result<Self>
    where
        Self: Sized;

    /// Start running this agent.
    #[allow(clippy::async_yields_async)]
    async fn run(&self) -> Instrumented<JoinHandle<Result<()>>>;
}

/// A trait for an abacus agent.
/// Adds assumptions for the indexer and metric methods.
///
/// To use the default implementation you must `impl AsRef<AbacusAgentCore>`
#[async_trait]
pub trait Agent: BaseAgent {
    /// Return a handle to the DB
    fn db(&self) -> &DB;

    /// Return a reference to an Outbox contract
    fn outbox(&self) -> &CachingOutbox;

    /// Return a reference to an InterchainGasPaymaster contract
    fn interchain_gas_paymaster(&self) -> Option<&CachingInterchainGasPaymaster>;

    /// Get a reference to the inboxes map
    fn inboxes(&self) -> &HashMap<String, InboxContracts>;

    /// Get a reference to an inbox's contracts by its name
    fn inbox_by_name(&self, name: &str) -> Option<&InboxContracts>;
}

#[async_trait]
impl<B> Agent for B
where
    B: BaseAgent + AsRef<AbacusAgentCore>,
{
    fn db(&self) -> &DB {
        &self.as_ref().db
    }

    fn outbox(&self) -> &CachingOutbox {
        &self.as_ref().outbox
    }

    fn interchain_gas_paymaster(&self) -> Option<&CachingInterchainGasPaymaster> {
        self.as_ref().interchain_gas_paymaster.as_ref()
    }

    fn inboxes(&self) -> &HashMap<String, InboxContracts> {
        &self.as_ref().inboxes
    }

    fn inbox_by_name(&self, name: &str) -> Option<&InboxContracts> {
        self.inboxes().get(name)
    }
}

/// Call this from `main` to fully initialize and run the agent for its entire
/// lifecycle. This assumes only a single agent is being run. This will
/// initialize the metrics server and tracing as well.
pub async fn agent_main<A: BaseAgent>() -> Result<()> {
    #[cfg(feature = "oneline-errors")]
    crate::oneline_eyre::install()?;
    #[cfg(all(feature = "color_eyre", not(feature = "oneline-errors")))]
    color_eyre::install()?;
    #[cfg(not(any(feature = "color-eyre", feature = "oneline-eyre")))]
    eyre::install()?;

    let settings = A::Settings::new().map_err(|e| e.into())?;
    let core_settings: &AgentSettings = settings.as_ref();

    let metrics = settings.as_ref().try_into_metrics(A::AGENT_NAME)?;
    core_settings.tracing.start_tracing(&metrics)?;
    let agent = A::from_settings(settings, metrics.clone()).await?;
    let _ = metrics.run_http_server();

    agent.run().await.await?
}

/// Utility to run multiple tasks and shutdown if any one task ends.
#[allow(clippy::unit_arg, unused_must_use)]
pub fn run_all(
    tasks: Vec<Instrumented<JoinHandle<Result<(), Report>>>>,
) -> Instrumented<JoinHandle<Result<()>>> {
    debug_assert!(!tasks.is_empty(), "No tasks submitted");
    let span = info_span!("run_all");
    tokio::spawn(async move {
        let (res, _, remaining) = select_all(tasks).await;

        for task in remaining.into_iter() {
            cancel_task!(task);
        }

        res?
    })
    .instrument(span)
}
