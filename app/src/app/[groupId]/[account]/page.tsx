import { SMSService } from "@/services/sms";

interface PageProps {
  params: {
    groupId: string;
    account: string;
  };
  searchParams: {};
}

export default function Page({
  params: { groupId, account },
  searchParams: {},
}: PageProps) {
  const rpcUrl = process.env.RPC_URL;
  const ipfsUrl = process.env.IPFS_URL;

  if (!rpcUrl || !ipfsUrl) {
    throw new Error("Missing environment variables");
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div>Hello</div>
      {groupId} {account}
    </main>
  );
}
