import { Module } from '@nestjs/common';
import { CompanyService } from './company.service';
import { CompanyController } from './company.controller';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from 'src/user/entities/user.entity';
import { Company } from './entities/company.entity';
import { HistoryModule } from 'src/history/history.module';
import { Note } from 'src/note/entities/note.entity';
import { NoteModule } from 'src/note/note.module';
@Module({
  controllers: [CompanyController],
  imports: [TypeOrmModule.forFeature([Company, User]), HistoryModule, NoteModule], 
  providers: [CompanyService],
  exports: [CompanyService],})
export class CompanyModule {}
