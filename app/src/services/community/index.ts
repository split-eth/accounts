import { Config } from "@citizenwallet/sdk";
import { existsSync, readFileSync } from "fs";
import path from "path";

export const communityFileExists = (): boolean => {
    const filePath = path.join(process.cwd(), "./community.json");
    return existsSync(filePath);
  };

export const readCommunityFile = (): Config | undefined => {
    if (!communityFileExists()) {
      return undefined;
    }
  
    // read community.json file
    const filePath = path.join(process.cwd(), "./community.json");
    const fileContents = readFileSync(filePath, "utf8");
    const config = JSON.parse(fileContents) as Config;
    return config;
  };