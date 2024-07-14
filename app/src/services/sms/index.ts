import { PublishCommand, SNSClient, SNSClientConfig } from "@aws-sdk/client-sns";

export class SMSService {
  private client: SNSClient;

  constructor() {
    const region = process.env.AWS_REGION;
    if (!region) {
      throw new Error("Missing environment variable AWS_REGION");
    }
    const accessKeyId = process.env.AWS_ACCESS_KEY_ID;
    const secretAccessKey = process.env.AWS_SECRET_ACCESS_KEY;
    if (!accessKeyId || !secretAccessKey) {
      throw new Error(
        "Missing environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
      );
    }

    const config: SNSClientConfig = {
      region,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    };

    this.client = new SNSClient({ region });
  }

  async sendSMS(phoneNumber: string, message: string) {
    try {
        console.log('sending sms', phoneNumber, message);
      const params = {
        Message: message,
        PhoneNumber: phoneNumber,
      };
      const command = new PublishCommand(params);
      const response = await this.client.send(command);
      console.log("Message sent:", response);
      return response;
    } catch (error) {
      console.error("Error sending SMS:", error);
      throw error;
    }
  }
}
