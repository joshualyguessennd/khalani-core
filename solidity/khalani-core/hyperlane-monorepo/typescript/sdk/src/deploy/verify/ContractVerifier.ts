import fetch from 'cross-fetch';
import { Debugger, debug } from 'debug';
import { ethers } from 'ethers';

import { utils } from '@hyperlane-xyz/utils';

import { MultiProvider } from '../../providers/MultiProvider';
import { ChainMap, ChainName } from '../../types';
import { MultiGeneric } from '../../utils/MultiGeneric';

import {
  CompilerOptions,
  ContractVerificationInput,
  VerificationInput,
} from './types';

enum ExplorerApiActions {
  VERIFY_IMPLEMENTATION = 'verifysourcecode',
  MARK_PROXY = 'verifyproxycontract',
  CHECK_STATUS = 'checkverifystatus',
  CHECK_PROXY_STATUS = 'checkproxyverification',
}

enum ExplorerApiErrors {
  ALREADY_VERIFIED = 'Contract source code already verified',
  VERIFICATION_PENDING = 'Pending in queue',
  PROXY_FAILED = 'A corresponding implementation contract was unfortunately not detected for the proxy address.',
}

export class ContractVerifier<Chain extends ChainName> extends MultiGeneric<
  Chain,
  VerificationInput
> {
  protected logger: Debugger;

  constructor(
    verificationInputs: ChainMap<Chain, VerificationInput>,
    protected readonly multiProvider: MultiProvider<Chain>,
    protected readonly apiKeys: ChainMap<Chain, string>,
    protected readonly flattenedSource: string, // flattened source code from eg `hardhat flatten`
    protected readonly compilerOptions: CompilerOptions,
  ) {
    super(verificationInputs);
    this.logger = debug('hyperlane:ContractVerifier');
  }

  verify(): Promise<PromiseSettledResult<void>[]> {
    return Promise.allSettled(
      this.chains().map((chain) => this.verifyChain(chain, this.get(chain))),
    );
  }

  async verifyChain(chain: Chain, inputs: VerificationInput): Promise<void> {
    this.logger(`Verifying ${chain}...`);
    const chainLogger = this.logger.extend(chain);
    for (const input of inputs) {
      await this.verifyContract(chain, input, chainLogger);
    }
  }

  private async submitForm(
    chain: Chain,
    action: ExplorerApiActions,
    options?: Record<string, string>,
  ): Promise<any> {
    const chainConnection = this.multiProvider.getChainConnection(chain);
    const apiUrl = chainConnection.getApiUrl();

    const params = new URLSearchParams({
      apikey: this.apiKeys[chain],
      module: 'contract',
      action,
      ...options,
    });

    let response: Response;
    if (
      action === ExplorerApiActions.CHECK_STATUS ||
      action === ExplorerApiActions.CHECK_PROXY_STATUS
    ) {
      response = await fetch(`${apiUrl}?${params}`);
    } else {
      response = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: params,
      });
    }

    // avoid rate limiting (5 requests per second)
    await utils.sleep(1000 / 5);

    const result = JSON.parse(await response.text());
    if (result.message === 'NOTOK') {
      switch (result.result) {
        case ExplorerApiErrors.VERIFICATION_PENDING:
          await utils.sleep(5000);
          return this.submitForm(chain, action, options);
        case ExplorerApiErrors.ALREADY_VERIFIED:
          return;
        case ExplorerApiErrors.PROXY_FAILED:
        default:
          throw new Error(`Verification failed: ${result.result}`);
      }
    }

    return result.result;
  }

  async verifyContract(
    chain: Chain,
    input: ContractVerificationInput,
    logger = this.logger,
  ): Promise<void> {
    if (input.address === ethers.constants.AddressZero) {
      return;
    }

    logger(`Checking ${input.address} (${input.name})...`);

    const data = {
      sourceCode: this.flattenedSource,
      contractname: input.name,
      contractaddress: input.address,
      // TYPO IS ENFORCED BY API
      constructorArguements: utils.strip0x(input.constructorArguments ?? ''),
      ...this.compilerOptions,
    };

    const guid = await this.submitForm(
      chain,
      ExplorerApiActions.VERIFY_IMPLEMENTATION,
      data,
    );

    const addressUrl = await this.multiProvider
      .getChainConnection(chain)
      .getAddressUrl(input.address);

    // poll for verified status
    if (guid) {
      await this.submitForm(chain, ExplorerApiActions.CHECK_STATUS, { guid });
    }
    logger(`Already verified at ${addressUrl}#code`);

    // mark as proxy (if applicable)
    if (input.isProxy) {
      const proxyGuid = await this.submitForm(
        chain,
        ExplorerApiActions.MARK_PROXY,
        {
          address: input.address,
        },
      );
      // poll for verified proxy status
      if (proxyGuid) {
        await this.submitForm(chain, ExplorerApiActions.CHECK_PROXY_STATUS, {
          guid: proxyGuid,
        });
      }
      logger(`Already verified at ${addressUrl}#readProxyContract`);
    }
  }
}
