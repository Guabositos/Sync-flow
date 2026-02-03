export class MessageResponseDto {
  id: number;
  content: string;
  createdAt: Date;
  sender: {
    id: number;
    username: string;
  };
}