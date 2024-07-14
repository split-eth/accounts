// api/sms

import { SMSService } from "@/services/sms";
import { randomString } from "@/utils/random";
import { hexlify, JsonRpcProvider, keccak256, toUtf8Bytes } from "ethers";
import { getBytes, hashMessage, verifyMessage } from "ethers";
import { solidityPackedKeccak256, Wallet } from "ethers";
import groupAbi from "@/assets/Group.abi.json";
import { Contract } from "ethers";

interface SplitRequest {
  group: string;
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

    const body = (await req.json()) as SplitRequest;
    console.log("body", body);
    const { group } = body;
    if (!group) {
      console.log("Missing data in request");
      return Response.json(
        { message: "Missing data in request" },
        { status: 400 }
      );
    }

    // Set up the provider (e.g., Infura, Alchemy, or a local node)
    const rpc = new JsonRpcProvider(process.env.RPC_URL);

    const provider = new Wallet(providerKey);

    const connectedProvider = provider.connect(rpc);

    const contract = new Contract(group, groupAbi["abi"], connectedProvider);

    const isFunded = await contract.isFunded();
    if (!isFunded) {
      return Response.json({ message: "Group is not funded" }, { status: 400 });
    }

    const tx = await contract.splitFunds();

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
