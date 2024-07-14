// api/sms

import { SMSService } from "@/services/sms";
import { randomString } from "@/utils/random";
import { hexlify, JsonRpcProvider, keccak256, toUtf8Bytes } from "ethers";
import { getBytes, hashMessage, verifyMessage } from "ethers";
import { solidityPackedKeccak256, Wallet } from "ethers";
import factoryAbi from "@/assets/SessionAccountManager.abi.json";
import accountAbi from "@/assets/SessionAccount.abi.json";
import { Contract } from "ethers";

interface StartRequest {
  secondFactor: string;
  salt: string;
  saltSignature: string;
  sessionAddress: string;
  sessionSignature: string;
}

export async function POST(req: Request) {
  try {
    const providerKey = process.env.PROVIDER_KEY;
    if (!providerKey) {
      return Response.json(
        { message: "Missing environment variable PROVIDER_KEY" },
        { status: 500 }
      );
    }

    const sessionManagerContractAddress =
      process.env.SESSION_MANAGER_CONTRACT_ADDRESS;
    if (!sessionManagerContractAddress) {
      return Response.json(
        {
          message:
            "Missing environment variable SESSION_MANAGER_CONTRACT_ADDRESS",
        },
        { status: 500 }
      );
    }

    const body = (await req.json()) as StartRequest;
    console.log("body", body);
    const {
      secondFactor,
      salt,
      sessionAddress,
      saltSignature,
      sessionSignature,
    } = body;
    if (
      !secondFactor ||
      !salt ||
      !sessionAddress ||
      !saltSignature ||
      !sessionSignature
    ) {
      console.log("Missing data in request");
      return Response.json(
        { message: "Missing data in request" },
        { status: 400 }
      );
    }

    // Set up the provider (e.g., Infura, Alchemy, or a local node)
    const rpc = new JsonRpcProvider(process.env.RPC_URL);

    const provider = new Wallet(providerKey);

    const saltHash = solidityPackedKeccak256(
      ["address", "bytes32", "address", "string"],
      [
        provider.address,
        hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0"),
        sessionAddress,
        salt,
      ]
    );

    const recoveredSaltOwner = verifyMessage(getBytes(saltHash), saltSignature);
    if (recoveredSaltOwner !== sessionAddress) {
      // unauthorized
      return Response.json({ message: "Unauthorized" }, { status: 401 });
    }

    const connectedProvider = provider.connect(rpc);

    const contract = new Contract(
      sessionManagerContractAddress,
      factoryAbi["abi"],
      connectedProvider
    );

    const providerHash = solidityPackedKeccak256(
      ["address", "bytes32"],
      [provider.address, hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0")]
    );

    console.log("providerHash", providerHash);
    // const rh = await contract.getFunction("getAccountHash")(
    //   provider.address,
    //   hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0")
    // );

    // console.log("rh", rh);

    const recoveredSessionOwner = verifyMessage(
      getBytes(providerHash),
      sessionSignature
    );

    if (recoveredSessionOwner !== sessionAddress) {
      // unauthorized
      return Response.json({ message: "Unauthorized" }, { status: 401 });
    }

    const account = await contract.getFunction("getAddress")(
      provider.address,
      hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0")
    );

    const accountContract = new Contract(
      account,
      accountAbi["abi"],
      connectedProvider
    );

    const code = await accountContract.getDeployedCode();
    if (code == null || code === "0x") {
      // need to deploy
      const tx = await contract.createAccount(
        provider.address,
        hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0")
      );

      await tx.wait();
    }

    const tx = await accountContract.startSession(sessionAddress, 2592000);

    // await tx.wait();

    // const providerSignature = await provider.signMessage(
    //   getBytes(providerHash)
    // );

    // console.log(
    //   "startSession",
    //   provider.address,
    //   hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0"),
    //   sessionAddress,
    //   providerSignature,
    //   sessionSignature
    // );

    // const tx = await contract.startSession(
    //   provider.address,
    //   hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0"),
    //   sessionAddress,
    //   providerSignature,
    //   sessionSignature
    // );

    console.log("Transaction Hash:", tx.hash);

    // Wait for the transaction to be mined
    const receipt = await tx.wait();
    console.log("Transaction was mined in block", receipt.blockNumber);

    return Response.json(
      {
        receipt,
        tx,
      },
      { status: 200 }
    );
  } catch (error: any) {
    console.log("Error writing file", error);
    return Response.json(
      { message: "Error writing file", error: error.message },
      { status: 500 }
    );
  }
}
