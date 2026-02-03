import { IsString, IsNotEmpty, MinLength } from 'class-validator';

export class CreateChatDto {
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  name: string;
}