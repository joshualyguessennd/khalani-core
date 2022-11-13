import debug from 'debug';
import { ethers } from 'ethers';

import { Inbox, Ownable } from '@hyperlane-xyz/core';
import type { types } from '@hyperlane-xyz/utils';

import { chainMetadata } from '../../consts/chainMetadata';
import { CoreContractsMap, HyperlaneCore } from '../../core/HyperlaneCore';
import {
  CoreContracts,
  InboxContracts,
  OutboxContracts,
  coreFactories,
} from '../../core/contracts';
import { ChainConnection } from '../../providers/ChainConnection';
import { MultiProvider } from '../../providers/MultiProvider';
import { BeaconProxyAddresses, ProxiedContract } from '../../proxy';
import { ChainMap, ChainName, RemoteChainMap, Remotes } from '../../types';
import { objMap, promiseObjAll } from '../../utils/objects';
import { HyperlaneDeployer } from '../HyperlaneDeployer';

import { CoreConfig, ValidatorManagerConfig } from './types';

export class HyperlaneCoreDeployer<
  Chain extends ChainName,
> extends HyperlaneDeployer<
  Chain,
  CoreConfig,
  CoreContracts<Chain, Chain>,
  typeof coreFactories
> {
  startingBlockNumbers: ChainMap<Chain, number | undefined>;

  constructor(
    multiProvider: MultiProvider<Chain>,
    configMap: ChainMap<Chain, CoreConfig>,
    factoriesOverride = coreFactories,
  ) {
    super(multiProvider, configMap, factoriesOverride, {
      logger: debug('hyperlane:CoreDeployer'),
    });
    this.startingBlockNumbers = objMap(configMap, () => undefined);
  }

  // override return type for inboxes shape derived from chain
  async deploy(
    partialDeployment?: Partial<CoreContractsMap<Chain>>,
  ): Promise<CoreContractsMap<Chain>> {
    return super.deploy(partialDeployment) as Promise<CoreContractsMap<Chain>>;
  }

  async deployOutbox<LocalChain extends Chain>(
    chain: LocalChain,
    config: ValidatorManagerConfig,
    ubcAddress: types.Address,
  ): Promise<OutboxContracts> {
    const domain = chainMetadata[chain].id;
    const outboxValidatorManager = await this.deployContract(
      chain,
      'outboxValidatorManager',
      [domain, config.validators, config.threshold],
    );

    const outbox = await this.deployProxiedContract(
      chain,
      'outbox',
      [domain],
      ubcAddress,
      [outboxValidatorManager.address],
    );
    return { outbox, outboxValidatorManager };
  }

  async deployInbox<Local extends Chain>(
    localChain: Local,
    remoteChain: Remotes<Chain, Local>,
    config: ValidatorManagerConfig,
    ubcAddress: types.Address,
    duplicate?: ProxiedContract<Inbox, BeaconProxyAddresses>,
  ): Promise<InboxContracts> {
    const localDomain = chainMetadata[localChain].id;
    const remoteDomain = chainMetadata[remoteChain].id;
    const inboxValidatorManager = await this.deployContract(
      localChain,
      'inboxValidatorManager',
      [remoteDomain, config.validators, config.threshold],
    );

    const initArgs: Parameters<Inbox['initialize']> = [
      remoteDomain,
      inboxValidatorManager.address,
    ];
    let inbox: ProxiedContract<Inbox, BeaconProxyAddresses>;
    if (duplicate) {
      inbox = await this.duplicateProxiedContract(
        localChain,
        duplicate,
        initArgs,
      );
    } else {
      inbox = await this.deployProxiedContract(
        localChain,
        'inbox',
        [localDomain],
        ubcAddress,
        initArgs,
      );
    }
    return { inbox, inboxValidatorManager };
  }

  async deployContracts<LocalChain extends Chain>(
    chain: LocalChain,
    config: CoreConfig,
  ): Promise<CoreContracts<Chain, LocalChain>> {
    if (config.remove) {
      // skip deploying to chains configured to be removed
      return undefined as any;
    }

    const dc = this.multiProvider.getChainConnection(chain);
    const provider = dc.provider!;
    const startingBlockNumber = await provider.getBlockNumber();
    this.startingBlockNumbers[chain] = startingBlockNumber;

    const upgradeBeaconController = await this.deployContract(
      chain,
      'upgradeBeaconController',
      [],
    );

    const interchainGasPaymaster = await this.deployProxiedContract(
      chain,
      'interchainGasPaymaster',
      [],
      upgradeBeaconController.address,
      [],
    );

    const connectionManager = await this.deployContract(
      chain,
      'connectionManager',
      [],
    );

    const outbox = await this.deployOutbox(
      chain,
      config.validatorManager,
      upgradeBeaconController.address,
    );
    await super.runIfOwner(chain, connectionManager, async () => {
      const current = await connectionManager.outbox();
      if (current !== outbox.outbox.address) {
        const outboxTx = await connectionManager.setOutbox(
          outbox.outbox.address,
          dc.overrides,
        );

        await dc.handleTx(outboxTx);
      }
    });

    const configChains = Object.keys(this.configMap) as Chain[];
    const remotes = this.multiProvider
      .intersect(configChains, false)
      .multiProvider.remoteChains(chain);

    const inboxes: Partial<Record<Chain, InboxContracts>> =
      this.deployedContracts[chain]?.inboxes ?? ({} as any);

    let prev: Chain | undefined;
    for (const remote of remotes) {
      if (!inboxes[remote]) {
        inboxes[remote] = await this.deployInbox(
          chain,
          remote,
          this.configMap[remote].validatorManager,
          upgradeBeaconController.address,
          inboxes[prev]?.inbox,
        );
      }

      await super.runIfOwner(chain, connectionManager, async () => {
        const isEnrolled = await connectionManager.isInbox(
          inboxes[remote]!.inbox.address,
        );
        if (!isEnrolled) {
          this.logger(`Enrolling inbox for remote '${remote}'`);
          const enrollTx = await connectionManager.enrollInbox(
            chainMetadata[remote].id,
            inboxes[remote]!.inbox.address,
            dc.overrides,
          );
          await dc.handleTx(enrollTx);
        }
      });
      prev = remote;
    }

    return {
      upgradeBeaconController,
      connectionManager,
      interchainGasPaymaster,
      inboxes: inboxes as RemoteChainMap<Chain, LocalChain, InboxContracts>,
      ...outbox,
    };
  }

  static async transferOwnership<CoreChains extends ChainName>(
    core: HyperlaneCore<CoreChains>,
    owners: ChainMap<CoreChains, types.Address>,
    multiProvider: MultiProvider<CoreChains>,
  ): Promise<ChainMap<CoreChains, ethers.ContractReceipt[]>> {
    return promiseObjAll(
      objMap(core.contractsMap, async (chain, coreContracts) =>
        HyperlaneCoreDeployer.transferOwnershipOfChain(
          coreContracts,
          owners[chain],
          multiProvider.getChainConnection(chain),
        ),
      ),
    );
  }

  static async transferOwnershipOfChain<
    Chain extends ChainName,
    Local extends Chain,
  >(
    coreContracts: CoreContracts<Chain, Local>,
    owner: types.Address,
    chainConnection: ChainConnection,
  ): Promise<ethers.ContractReceipt[]> {
    const ownables: Ownable[] = [
      coreContracts.outbox.contract,
      coreContracts.outboxValidatorManager,
      coreContracts.connectionManager,
      coreContracts.upgradeBeaconController,
      ...Object.values<InboxContracts>(coreContracts.inboxes).flatMap(
        (inbox) => [inbox.inbox.contract, inbox.inboxValidatorManager],
      ),
    ];
    return Promise.all(
      ownables.map((ownable) =>
        chainConnection.handleTx(
          ownable.transferOwnership(owner, chainConnection.overrides),
        ),
      ),
    );
  }
}
