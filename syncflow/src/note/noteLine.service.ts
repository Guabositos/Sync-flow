import { Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { CreateNoteDto } from './dto/create-note.dto';
import { UpdateNoteLineDto } from './dto/update-noteLine.dto';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import { SharedService } from 'src/services/shared.services';
import { NoteLine } from './entities/noteline.entity';
import { User } from 'src/user/entities/user.entity';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { Note } from './entities/note.entity';
import { InjectRepository } from '@nestjs/typeorm';
import { DeepPartial, Repository } from 'typeorm';
import { CreateEventService } from 'src/history/create-event.service';
import { OperationType } from 'src/enum/operation-type';
import { Task } from 'src/task/entities/task.entity';
import { use } from 'passport';

@Injectable()
export class NoteLineService extends SharedService<NoteLine> {
  @InjectRepository(Note) notesRepo: Repository<Note>
  constructor(@InjectRepository(NoteLine) repo: Repository<NoteLine>,
    private readonly cEventService: CreateEventService) {
    super(repo, cEventService);
  }

  async update(id:number, data: UpdateNoteLineDto, userID?): Promise<NoteLine | null> {
    console.log("Update called with id:", data);
    const entity = await this.repository.findOne({ where: { lineNumber: data.lineNumber, note: { id: id } } });
    const user = await this.repository.manager.getRepository(User).findOne({ where: { id: userID } });
    if (user == null) {
      throw new InternalServerErrorException(`User with id ${userID} not found`);
    }
    if (!entity) {
      throw new NotFoundException(`Entity with id ${id} not found`);
    }
    const { lineNumber, ...act_data } = data;
    console.log("act_data", act_data as DeepPartial<NoteLine>);
    const updated = await super.update(entity.id, act_data as DeepPartial<NoteLine>, userID);
    if (updated == null) {
      return null;
    }
    this.repository.update(entity.id, { lastEditedBy: user });
    const newData = await this.repository.findOne({ where: { id: entity.id }, select: { lineNumber : true , content: true, color: true, fontSize: true, highlighted: true, lastEditedBy : {id: true} } });
    return newData;
  }

  async updateWithoutEvent(id, data: UpdateNoteLineDto, userID?): Promise<DeepPartial<NoteLine> | null> {
    const entity = await this.repository.findOne({ where: { lineNumber: data.lineNumber, note: { id: data.noteId } } });
    const user = await this.repository.manager.getRepository(User).findOne({ where: { id: userID } });
    if (user == null) {
      throw new InternalServerErrorException(`User with id ${userID} not found`);
    }
    if (!entity) {
      throw new NotFoundException(`Entity with id ${id} not found`);
    }
    const { noteId, lineNumber, ...act_data } = data;
    console.log("act_data", act_data as DeepPartial<NoteLine>);
    const updated1 = await this.repository.merge(entity, data);
    const updated = await this.repository.save(updated1);
    if (updated == null) {
      return null;
    }
    this.repository.update(entity.id, { lastEditedBy: user });
    return {
      ...data,
      updatedAt: updated.updatedAt,
    }
  }

  async createMultiple(n: number, noteId: number): Promise<{
    noteId: number;
    newLineCount: number;
    newLines: { lineNumber: number; content: string }[];
  }> {
    console.log("createMultiple called with n:", n, "and noteId:", noteId);

    const notes = await this.notesRepo.find({ where: { id: noteId } });
    if (notes.length !== 1) {
      throw new NotFoundException(`Note with id ${noteId} not found`);
    }
    const note = notes[0];

    const noteLines: NoteLine[] = [];
    for (let i = 0; i < n; i++) {
      const noteLine = new NoteLine();
      noteLine.lineNumber = note.lineCount + i + 1;
      noteLine.note = note;
      noteLine.content = '';
      noteLines.push(noteLine);
    }

    const savedNoteLines = await this.repository.save(noteLines);

    const newLineCount = savedNoteLines.length + note.lineCount;
    console.log("New line count:", newLineCount);

    await this.notesRepo.update(noteId, {
      updatedAt: new Date(),
      lineCount: newLineCount,
    });

    const newLines = savedNoteLines.map(line => ({
      lineNumber: line.lineNumber,
      content: line.content,
      id: line.id,
      fontsize: line.fontSize,
      color: line.color,
      highlighted: line.highlighted,
    }));
    console.log("New lines created:", newLines);

    return {
      noteId,
      newLineCount,
      newLines,
    };
  }



  async getNoteLinesByNoteId(noteId: number, start: number = 0, limit: number = 0): Promise<any[]> {
    const note = await this.notesRepo.findOne({ where: { id: noteId } });
    if (!note) {
      throw new NotFoundException(`Note with id ${noteId} not found`);
    }
    const take = limit > 0 ? limit : 100;
    console.log("Fetching note lines for noteId:", noteId, "with start:", start, "and limit:", take);
    const rawNoteLines = await this.repository.createQueryBuilder("noteline")

      .where("noteline.noteId = :noteId", { noteId })
      .andWhere("noteline.deletedAt IS NULL")
      .select([
        "noteline.id",
        "noteline.lineNumber",
        "noteline.content",
        "noteline.updatedAt",
        "noteline.highlighted",
        "noteline.fontSize",
        "noteline.color"
      ])
      .addSelect("noteline.lastEditedById")
      .orderBy("noteline.lineNumber", "ASC")
      .skip(start ? start : 0)
      .limit(take)
      .getRawMany();
    const noteLines = rawNoteLines.map(raw => ({
      id: raw.noteline_id,
      lineNumber: raw.noteline_lineNumber,
      content: raw.noteline_content,
      updatedAt: raw.noteline_updatedAt,
      highlighted: Boolean(raw.noteline_highlighted),
      fontSize: raw.noteline_fontSize,
      color: raw.noteline_color,
      lastEditedById: raw.lastEditedById,
    }));

    console.log("noteLines", noteLines);

    return noteLines;
  }
  // async create(createNoteDto: CreateNoteDto, user: JwtPayload): Promise<NoteLine |null> {
  //     return this.sharedService.create(createNoteDto, user);
  // }

  // async findAll(): Promise<NoteLine[]> {
  //     return this.sharedService.findAllNoteLines();
  // }

  // async findOne(id: string): Promise<NoteLine> {
  //     return this.sharedService.findOneNoteLine(id);
  // }

  // async update(updateNoteLineDto: UpdateNoteLineDto): Promise<NoteLine> {
  //     const NoteLine = await this.sharedService.update(user , updateNoteLineDto);
  //     if (!NoteLine) {
  //         throw new Error(`NoteLine with id ${id} not found`);
  //     }
  //     return NoteLine ;
  // }

  // async remove(id: string): Promise<void> {
  //     return this.sharedService.removeNoteLine(id);
  // }

}
