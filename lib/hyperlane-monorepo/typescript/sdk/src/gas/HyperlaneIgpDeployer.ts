import debug from 'debug';

import {
  InterchainGasPaymaster,
  OverheadIgp,
  ProxyAdmin,
  StorageGasOracle,
} from '@hyperlane-xyz/core';
import { types, utils } from '@hyperlane-xyz/utils';

import { HyperlaneContracts, filterOwnableContracts } from '../contracts';
import { HyperlaneDeployer } from '../deploy/HyperlaneDeployer';
import { MultiProvider } from '../providers/MultiProvider';
import { ChainName } from '../types';
import { pick } from '../utils/objects';

import { IgpFactories, igpFactories } from './contracts';
import { IgpConfig, OverheadIgpConfig } from './types';

export class HyperlaneIgpDeployer extends HyperlaneDeployer<
  OverheadIgpConfig,
  IgpFactories
> {
  constructor(multiProvider: MultiProvider) {
    super(multiProvider, igpFactories, {
      logger: debug('hyperlane:IgpDeployer'),
    });
  }

  async deployInterchainGasPaymaster(
    chain: ChainName,
    proxyAdmin: ProxyAdmin,
    storageGasOracle: StorageGasOracle,
    config: IgpConfig,
  ): Promise<InterchainGasPaymaster> {
    const owner = config.owner;
    const beneficiary = config.beneficiary;
    const igp = await this.deployProxiedContract(
      chain,
      'interchainGasPaymaster',
      proxyAdmin.address,
      [],
      [owner, beneficiary],
    );

    const gasOracleConfigsToSet: InterchainGasPaymaster.GasOracleConfigStruct[] =
      [];

    const remotes = Object.keys(config.gasOracleType);
    for (const remote of remotes) {
      const remoteId = this.multiProvider.getDomainId(remote);
      const currentGasOracle = await igp.gasOracles(remoteId);
      if (!utils.eqAddress(currentGasOracle, storageGasOracle.address)) {
        gasOracleConfigsToSet.push({
          remoteDomain: remoteId,
          gasOracle: storageGasOracle.address,
        });
      }
    }

    if (gasOracleConfigsToSet.length > 0) {
      await this.runIfOwner(chain, igp, async () =>
        this.multiProvider.handleTx(
          chain,
          igp.setGasOracles(gasOracleConfigsToSet),
        ),
      );
    }
    return igp;
  }

  async deployOverheadIgp(
    chain: ChainName,
    interchainGasPaymasterAddress: types.Address,
    config: OverheadIgpConfig,
  ): Promise<OverheadIgp> {
    const overheadInterchainGasPaymaster = await this.deployContract(
      chain,
      'defaultIsmInterchainGasPaymaster',
      [interchainGasPaymasterAddress],
    );

    // Only set gas overhead configs if they differ from what's on chain
    const configs: OverheadIgp.DomainConfigStruct[] = [];
    const remotes = Object.keys(config.overhead);
    for (const remote of remotes) {
      const remoteDomain = this.multiProvider.getDomainId(remote);
      const gasOverhead = config.overhead[remote];
      const existingOverhead =
        await overheadInterchainGasPaymaster.destinationGasOverhead(
          remoteDomain,
        );
      if (!existingOverhead.eq(gasOverhead)) {
        configs.push({ domain: remoteDomain, gasOverhead });
      }
    }

    if (configs.length > 0) {
      await this.runIfOwner(chain, overheadInterchainGasPaymaster, () =>
        this.multiProvider.handleTx(
          chain,
          overheadInterchainGasPaymaster.setDestinationGasOverheads(
            configs,
            this.multiProvider.getTransactionOverrides(chain),
          ),
        ),
      );
    }

    return overheadInterchainGasPaymaster;
  }

  async deployStorageGasOracle(chain: ChainName): Promise<StorageGasOracle> {
    return this.deployContract(chain, 'storageGasOracle', []);
  }

  async deployContracts(
    chain: ChainName,
    config: OverheadIgpConfig,
  ): Promise<HyperlaneContracts<IgpFactories>> {
    // NB: To share ProxyAdmins with HyperlaneCore, ensure the ProxyAdmin
    // is loaded into the contract cache.
    const proxyAdmin = await this.deployContract(chain, 'proxyAdmin', []);
    const storageGasOracle = await this.deployStorageGasOracle(chain);
    const interchainGasPaymaster = await this.deployInterchainGasPaymaster(
      chain,
      proxyAdmin,
      storageGasOracle,
      config,
    );
    const overheadIgp = await this.deployOverheadIgp(
      chain,
      interchainGasPaymaster.address,
      config,
    );
    const contracts = {
      proxyAdmin,
      storageGasOracle,
      interchainGasPaymaster,
      defaultIsmInterchainGasPaymaster: overheadIgp,
    };
    // Do not transfer ownership of StorageGasOracle, as it should be
    // owned by a "hot" key so that prices can be updated regularly
    const ownables = await filterOwnableContracts(contracts);
    const filteredOwnables = pick(
      ownables,
      Object.keys(contracts).filter((name) => name !== 'storageGasOracle'),
    );
    await this.transferOwnershipOfContracts(
      chain,
      config.owner,
      filteredOwnables,
    );
    return contracts;
  }
}
