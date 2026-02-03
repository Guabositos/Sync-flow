// src/company/dto/create-company-with-manager.dto.ts
import { IsString, MinLength } from 'class-validator';

export class CreateCompanyWithManagerDto {
  @IsString()
  companyName: string;
  
  @IsString()
  managerUsername: string;

  @IsString()
  @MinLength(6)
  managerPassword: string;
}
