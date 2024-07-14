// api/hash
import {  hashMessage } from "ethers";
import { solidityPackedKeccak256 } from "ethers";

interface HashRequest {
  types: string[];
  values: any[];
}

export async function POST(req: Request) {
  try {
    const body = (await req.json()) as HashRequest;
    const { types, values } = body;
    if (types.length === 0 || values.length === 0) {
      return Response.json(
        { message: "Missing data in request" },
        { status: 400 }
      );
    }

    if (types.length !== values.length) {
      return Response.json(
        { message: "Invalid data in request" },
        { status: 400 }
      );
    }

    const requestHash = solidityPackedKeccak256(types, values);
    console.log('values', values);

    return Response.json(
      {
        hash: requestHash,
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
