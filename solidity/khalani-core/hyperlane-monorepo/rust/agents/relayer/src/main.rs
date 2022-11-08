//! The relayer forwards signed checkpoints from the outbox to chain to inboxes
//!
//! At a regular interval, the relayer polls Outbox for signed checkpoints and
//! submits them as checkpoints on the inbox.

#![forbid(unsafe_code)]
#![warn(missing_docs)]
#![warn(unused_extern_crates)]

use eyre::Result;

use abacus_base::agent_main;

use crate::relayer::Relayer;

mod checkpoint_fetcher;
mod merkle_tree_builder;
mod msg;
mod prover;
mod relayer;
mod settings;

#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<()> {
    agent_main::<Relayer>().await
}
