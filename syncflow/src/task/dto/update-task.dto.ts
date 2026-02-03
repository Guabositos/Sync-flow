import { PartialType } from '@nestjs/mapped-types';
import { CreateTaskDto } from './create-task.dto';
import { IsEmpty, IsEnum, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';
import { isNullableType } from 'graphql';

export class UpdateTaskDto  {
  @IsNotEmpty()
  id: number;

  @IsOptional()
  title: string;

  @IsOptional()
  description: string;

  @IsOptional()
  dueDate: Date;

  @IsEmpty()
  assignedToId: number;

}
