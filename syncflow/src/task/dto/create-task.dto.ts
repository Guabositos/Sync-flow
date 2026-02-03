import { IsString, IsOptional, IsDate, IsNumber, IsBoolean } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateTaskDto {
  @IsString()
  title: string;

  @IsString()
  @IsOptional()
  description?: string;

  @IsDate()
  @Type(() => Date)
  dueDate: Date;

  @IsNumber()
  @IsOptional()
  assignedToId?: number;

  @IsBoolean()
  @IsOptional()
  completed?: boolean;
}
