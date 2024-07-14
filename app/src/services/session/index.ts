import { Config } from "@citizenwallet/sdk";
import { BundlerService } from "@citizenwallet/sdk/dist/src/services/bundler";
import { BaseWallet } from "ethers";
import { Wallet } from "ethers";

class SessionService {
    signer: BaseWallet;

    bundler: BundlerService;

    constructor(config: Config) {
        const signerKey = localStorage.getItem('spliteth-signerKey');
        if (signerKey) {
            this.signer = new Wallet(signerKey);

            this.bundler = new BundlerService(config);
            return;
        }

        // generate new key
        this.signer = Wallet.createRandom();

        localStorage.setItem('spliteth-signerKey', this.signer.privateKey);

        this.bundler = new BundlerService(config);
    }
}