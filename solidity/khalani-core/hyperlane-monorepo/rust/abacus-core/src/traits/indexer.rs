//! An Indexer provides a common interface for bubbling up chain-specific
//! event-data to another entity (e.g. a `ContractSync`). For example, the only
//! way to retrieve data such as the chain's latest block number or a list of
//! checkpoints/messages emitted within a certain block range by calling out to
//! a chain-specific library and provider (e.g. ethers::provider). A
//! chain-specific outbox or inbox should implement one or both of the Indexer
//! traits (CommonIndexer or OutboxIndexer) to provide an common interface which
//! other entities can retrieve this chain-specific info.

use std::fmt::Debug;

use async_trait::async_trait;
use auto_impl::auto_impl;
use ethers::types::H256;
use eyre::Result;

use crate::{Checkpoint, InterchainGasPaymentWithMeta, LogMeta, RawCommittedMessage};

/// Interface for an indexer.
#[async_trait]
#[auto_impl(Box, Arc)]
pub trait Indexer: Send + Sync + Debug {
    /// Get the chain's latest block number that has reached finality
    async fn get_finalized_block_number(&self) -> Result<u32>;
}

/// Interface for Outbox contract indexer. Interface for allowing other
/// entities to retrieve chain-specific data from an outbox.
#[async_trait]
#[auto_impl(Box, Arc)]
pub trait OutboxIndexer: Indexer {
    /// Fetch list of messages between blocks `from` and `to`.
    async fn fetch_sorted_messages(
        &self,
        from: u32,
        to: u32,
    ) -> Result<Vec<(RawCommittedMessage, LogMeta)>>;

    /// Fetch sequentially sorted list of cached checkpoints between blocks
    /// `from` and `to`
    async fn fetch_sorted_cached_checkpoints(
        &self,
        from: u32,
        to: u32,
    ) -> Result<Vec<(Checkpoint, LogMeta)>>;
}

/// Interface for Inbox contract indexer. Interface for allowing other entities
/// to retrieve chain-specific data from an inbox.
#[async_trait]
#[auto_impl(Box, Arc)]
pub trait InboxIndexer: Indexer {
    /// Fetch a list of processed message hashes between blocks `from` and `to`.
    async fn fetch_processed_messages(&self, from: u32, to: u32) -> Result<Vec<(H256, LogMeta)>>;
}

/// Interface for InterchainGasPaymaster contract indexer.
#[async_trait]
#[auto_impl(Box, Arc)]
pub trait InterchainGasPaymasterIndexer: Indexer {
    /// Fetch list of gas payments between `from_block` and `to_block`,
    /// inclusive
    async fn fetch_gas_payments(
        &self,
        from_block: u32,
        to_block: u32,
    ) -> Result<Vec<InterchainGasPaymentWithMeta>>;
}
