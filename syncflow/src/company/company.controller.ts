import { Controller, Get, Post, Body, Patch, Param, Delete } from '@nestjs/common';
import { CompanyService } from './company.service';
import { CreateCompanyWithManagerDto } from './dto/create-company-with-manager.dto';
import { Company } from './entities/company.entity';
@Controller('company')
export class CompanyController {
  constructor(private readonly companyService: CompanyService){}
  @Post('create-company')
  async createCompanyWithManager(
    @Body() dto: CreateCompanyWithManagerDto
  ): Promise<Company> {
    console.log('Received DTO:', dto);
    return this.companyService.createCompanyWithManager(dto);
  }

  @Get(':name')
  async isNameTaken(@Param('name') name: string): Promise<boolean> {
    return this.companyService.isNameTaken(name);
  } 
}