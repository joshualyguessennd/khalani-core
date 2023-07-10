use async_trait::async_trait;
use std::ops::Deref;

use derive_new::new;
use eyre::Context;
use tracing::instrument;

use hyperlane_core::{HyperlaneMessage, H256};

use super::{BaseMetadataBuilder, MetadataBuilder};

#[derive(Clone, Debug, new)]
pub struct RoutingIsmMetadataBuilder {
    base: BaseMetadataBuilder,
}

impl Deref for RoutingIsmMetadataBuilder {
    type Target = BaseMetadataBuilder;

    fn deref(&self) -> &Self::Target {
        &self.base
    }
}

#[async_trait]
impl MetadataBuilder for RoutingIsmMetadataBuilder {
    #[instrument(err, skip(self))]
    async fn build(
        &self,
        ism_address: H256,
        message: &HyperlaneMessage,
    ) -> eyre::Result<Option<Vec<u8>>> {
        const CTX: &str = "When fetching RoutingIsm metadata";
        let ism = self.build_routing_ism(ism_address).await.context(CTX)?;
        let module = ism.route(message).await.context(CTX)?;
        self.base.build(module, message).await.context(CTX)
    }
}
