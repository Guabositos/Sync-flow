import { Module } from '@nestjs/common';
import { NoteService } from './note.service';
import { NoteController } from './note.controller';
import { NoteLine } from './entities/noteline.entity';
import { NoteLineService } from './noteLine.service';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Company } from 'src/company/entities/company.entity';
import { User } from 'src/user/entities/user.entity';
import { Notesocket } from './note.gateway';
import { Note } from './entities/note.entity';
import { AuthModule } from 'src/auth/auth.module';
import { HistoryModule } from 'src/history/history.module';
import { CompanyModule } from 'src/company/company.module';
import { ConfigModule } from 'src/config/config.module';

@Module({
  controllers: [NoteController],
  providers: [NoteService, NoteLineService, Notesocket],
  imports: [TypeOrmModule.forFeature([Note, NoteLine, Company, User]), AuthModule, HistoryModule],
  exports: [NoteService, NoteLineService, TypeOrmModule.forFeature([Note, NoteLine])],
})
export class NoteModule {}
