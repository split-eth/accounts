interface PageProps {
  params: {};
  searchParams: {};
}

export default function Page({ params: {}, searchParams: {} }: PageProps) {
  const rpcUrl = process.env.RPC_URL;
  const ipfsUrl = process.env.IPFS_URL;

  if (!rpcUrl || !ipfsUrl) {
    throw new Error("Missing environment variables");
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24"></main>
  );
}
