import { walletClient, publicClient } from "@/conf/viem.ts";
import {
  DEFAULT_CURRENCY,
  DEFAULT_TOKEN_SYMBOL,
  TOKEN_CONSUMER_ABI,
  TOKEN_CONSUMER_ADDRESS,
} from "@/constants.ts";

(async () => {
  console.log(
    `📡 Sending price request for ${DEFAULT_TOKEN_SYMBOL}/${DEFAULT_CURRENCY}...`,
  );
  const hash = await walletClient.writeContract({
    address: TOKEN_CONSUMER_ADDRESS,
    abi: TOKEN_CONSUMER_ABI,
    functionName: "askForPrice",
    args: [DEFAULT_TOKEN_SYMBOL, DEFAULT_CURRENCY],
  });

  console.log(`✅ Transaction sent: ${hash}`);

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log("📬 Confirmed in block:", receipt.blockNumber);

  const res = (await publicClient.readContract({
    address: TOKEN_CONSUMER_ADDRESS,
    abi: TOKEN_CONSUMER_ABI,
    functionName: "getPrice",
    args: [DEFAULT_TOKEN_SYMBOL, DEFAULT_CURRENCY],
  })) as [bigint, bigint];

  const [price, date] = res;
  console.log(
    `💰 Last price: $${Number(price) / 1e8} ${DEFAULT_CURRENCY} updated ${new Date(Number(date) * 1000).toISOString()}`,
  );
})();
