const dotenv = require("dotenv");
const { hashMessage, solidityPackedKeccak256, Wallet } = require("ethers");

dotenv.config();

const main = async () => {
  const providerKey = process.env.PROVIDER_KEY;
  if (!providerKey) {
    return Response.json(
      { message: "Missing environment variable PROVIDER_KEY" },
      { status: 500 }
    );
  }

  const sessionKey =
    "7a9bbb765460f5bf28ae6ac1971ee888d2028a47755b04ec921f18030a1594b7";

  const wallet = new Wallet(sessionKey);

  const secondFactor = "+32478163203";
  const sessionAddress = wallet.address;

  const requestHash = hashMessage(
    solidityPackedKeccak256(
      ["string", "address"],
      [secondFactor, sessionAddress]
    )
  );

  const signature = await wallet.signMessage(requestHash);

  console.log("sessionAddress", sessionAddress);
  console.log("requestHash", requestHash);
  console.log("signature", signature);
};

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
