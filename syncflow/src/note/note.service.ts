import { ConflictException, Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { CreateNoteDto } from './dto/create-note.dto';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import { SharedService } from 'src/services/shared.services';
import { Note } from './entities/note.entity';
import { InjectRepository } from '@nestjs/typeorm';
import { CreateEventService } from 'src/history/create-event.service';
import { DeepPartial, Repository } from 'typeorm';
import { NoteLine } from './entities/noteline.entity';
import { OperationType } from 'src/enum/operation-type';
import { Task } from 'src/task/entities/task.entity';
import { User } from 'src/user/entities/user.entity';
import { CompanyService } from 'src/company/company.service';
import { Company } from 'src/company/entities/company.entity';
import { NoteLineService } from 'src/note/noteLine.service';
import { PaginationDto } from 'src/services/pagination.dto';
import { NoteSelectOptions } from './dto/select-note.dto';

@Injectable()
export class NoteService extends SharedService<Note> {
  constructor(
    @InjectRepository(Note) private readonly repo: Repository<Note>,
    @InjectRepository(Company) private readonly companyRepo: Repository<Company>,
    private readonly NoteLineService: NoteLineService,
    private readonly cEventService: CreateEventService
  ) {
    super(repo, cEventService);
  }

  async lineCount(noteId: number): Promise<number> {
    const note = await this.repo.findOne({
      where: { id: noteId },
      relations: ['lines'],
    });
    return note ? note.lines.length : 0;
  }
  async updateWithoutEvent(id: number, data: DeepPartial<Note>, userID?): Promise<DeepPartial<Note> | null> {
    const entity = await this.findOne(id);
    console.log('Entity found for update:', entity);
    if (!entity) {
      throw new NotFoundException(`Entity with id ${id} not found`);
    }
    const updated = this.repository.merge(entity, data);
    console.log('Updated entity:', updated);
     await this.repository.save(updated);
    const savedEntity = await this.findOne(id);
    return savedEntity;
  }

  async getNoteById(noteId: number): Promise<Note | null> {
    const temp = await this.repo.findOne({
      where: { id: noteId },
      select: NoteSelectOptions,
      relations: ['company'],
    });
    return temp;
  }

  async getnoteId(user: JwtPayload): Promise<Note | null> {
    const companyCode = user.companyCode;
    if (!companyCode) {
      throw new InternalServerErrorException('Company code is required');
    }
    const company = await this.companyRepo.findOne({
      where: { code: companyCode },
    });
    const companyId = company?.id;
    if (!companyId) {
      return null;
    }
    const temp = await this.repo.findOne({
      where: { company: { id: companyId } },
    });
    console.log('Note found for company:', temp);
    return temp;
  }

  async checkifUserInNote(user: JwtPayload, noteId: number): Promise<boolean> {
    const note = await this.repo.findOne({
      where: { id: noteId },
    });
    if (!note) {
      return false;
    }
    const company = await this.companyRepo.findOne({
      where: { code: user.companyCode },
      relations: ['users'],
    });
    if (!company) {
      return false;
    }
    const userInNote = company.users.some(u => u.id === user.sub);
    return userInNote;
  }



  async createNote(data: CreateNoteDto, manager: JwtPayload): Promise<Note> {
    const company = await this.companyRepo.findOne({
      where: { code: manager.companyCode },
    });
    if (!company) {
      throw new NotFoundException('Company not found for the manager');
    }
    const Note = await this.create({
      title: data.title ? data.title : 'Welcome',
      company: company,
      lines: [],
      lineCount: 0,
    }, manager.sub);
    if (Note == null) {
      throw new ConflictException('Note already exists');
    }
    const lineCount = data.lineCount || 10;
    await this.NoteLineService.createMultiple(lineCount, Note.id);
    const newNote = await this.getNoteById(Note.id);
    if(!newNote){
      throw new InternalServerErrorException('Failed to retrieve the newly created note');
    }
    return newNote;
  }

  async getallIds(user: JwtPayload, paginationDto?: PaginationDto): Promise<number[]> {
    const take = paginationDto?.limit || 20;
    const skip = paginationDto?.offset || 0;
    const notes = await this.repo.find({ where: { company: { code: user.companyCode } }, select: ['id'], take, skip });
    return notes.map(note => note.id);
  }
  async getNotesInfo(user: JwtPayload, paginationDto?: PaginationDto): Promise<{ id: number; title: string; lineCount: number; }[]> {
    const take = paginationDto?.limit || 20;
    const skip = paginationDto?.offset || 0;
    const notes = await this.repo.find({ where: { company: { code: user.companyCode } }, select: NoteSelectOptions, take, skip });
    return notes.map(note => ({
      id: note.id,
      title: note.title,
      lineCount: note.lineCount,
    }));
  }
}