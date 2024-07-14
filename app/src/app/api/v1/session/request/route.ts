// api/sms

import { SMSService } from "@/services/sms";
import { randomString } from "@/utils/random";
import {
  getBytes,
  hashMessage,
  hexlify,
  toUtf8Bytes,
  verifyMessage,
} from "ethers";
import { solidityPackedKeccak256, Wallet } from "ethers";

interface ProviderRequest {
  secondFactor: string;
  sessionAddress: string;
  signature: string;
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

    const body = (await req.json()) as ProviderRequest;
    const { secondFactor, sessionAddress, signature } = body;
    if (!secondFactor || !sessionAddress || !signature) {
      return Response.json(
        { message: "Missing data in request" },
        { status: 400 }
      );
    }

    const requestHash = solidityPackedKeccak256(
      ["address", "bytes32"],
      [sessionAddress, hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0")]
    );

    const recoveredSessionOwner = verifyMessage(
      getBytes(requestHash),
      signature
    );

    if (recoveredSessionOwner !== sessionAddress) {
      // unauthorized
      return Response.json({ message: "Unauthorized" }, { status: 401 });
    }

    const provider = new Wallet(providerKey);

    const randomCharacters = randomString(6);

    const responseHash = solidityPackedKeccak256(
      ["address", "bytes32", "address", "string"],
      [
        provider.address,
        hexlify(toUtf8Bytes(secondFactor)).padEnd(66, "0"),
        sessionAddress,
        randomCharacters,
      ]
    );

    console.log("provider.address", provider.address);

    const responseSignature = await provider.signMessage(
      getBytes(responseHash)
    );

    const smsService = new SMSService();

    const phoneNumber = secondFactor;
    const message = `Your spliteth code: ${randomCharacters}`;

    // await smsService.sendSMS(phoneNumber, message);
    console.log(message);

    return Response.json(
      {
        provider: provider.address,
        salt: secondFactor,
        sessionAddress,
        signature: responseSignature,
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
