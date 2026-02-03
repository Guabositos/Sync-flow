export class ChatResponseDto {
  id: number;
  name: string;
  type: string;
  createdAt: Date;
  messageCount?: number;
  lastMessage?: {
    content: string;
    senderUsername: string;
    createdAt: Date;
  };
}