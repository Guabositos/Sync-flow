// src/company/company.service.ts

import { Injectable, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Company } from './entities/company.entity';
import { User } from '../user/entities/user.entity';
import { Repository } from 'typeorm';
import { CreateCompanyWithManagerDto } from './dto/create-company-with-manager.dto';
import * as bcrypt from 'bcrypt';
import { Role } from '../enum/role.enum';
import { randomBytes } from 'crypto';
import { CreateEventService } from 'src/history/create-event.service';
import { OperationType } from 'src/enum/operation-type';
import { Note } from 'src/note/entities/note.entity';
import { NoteLine } from 'src/note/entities/noteline.entity';
import { NoteService } from 'src/note/note.service';
import { NoteLineService } from 'src/note/noteLine.service';
@Injectable()
export class CompanyService {
  constructor(
    @InjectRepository(Company)
    private companyRepository: Repository<Company>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private readonly NoteService: NoteService,
    private readonly NoteLineService: NoteLineService,
    private readonly createEventService: CreateEventService,
  ) {}

  async createCompanyWithManager(dto: CreateCompanyWithManagerDto): Promise<Company> {
    const { companyName, managerUsername, managerPassword } = dto;

    let companyCode = randomBytes(8).toString('hex');

    let existing = await this.companyRepository.findOne({ where: { code: companyCode } });
    while (existing) {
      companyCode = randomBytes(8).toString('hex');
      existing = await this.companyRepository.findOne({ where: { code: companyCode } });
    }

    const company = this.companyRepository.create({
      code: companyCode,
      name: companyName,
    });

    const savedCompany = await this.companyRepository.save(company);

    const salt = await bcrypt.genSalt();
    const hashedPassword = await bcrypt.hash(managerPassword, salt);
    const user = await this.userRepository.create({
      username: managerUsername,
      password: hashedPassword,
      salt,
      role: Role.MANAGER,
      company: savedCompany,
    });
    const manager = await this.userRepository.save(user);
    return savedCompany;
  }
  async findByCode(code: string): Promise<Company | null> {
    console.log(`Searching for company with code: ${code}`);
    return this.companyRepository.findOne({ where: { code } });
  }
  
  async getCompanyById(id: number): Promise<Company | null> {
    return this.companyRepository.findOne({ where: { id },select:{name:true, code:true, id:false, deletedAt:false}},);
  }

  async isNameTaken(name: string): Promise<boolean> {
    const company = await this.companyRepository.findOne({ where: { name:name } });
    return !!company;
  }
}
