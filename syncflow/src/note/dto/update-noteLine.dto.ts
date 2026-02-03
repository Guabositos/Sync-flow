import { PartialType } from '@nestjs/mapped-types';
import { CreateNoteDto } from './create-note.dto';
export class UpdateNoteLineDto {
  lineNumber: number;
  content?: string;
  noteId?: number;
  updatedAt?: Date;
  color?: string;
  fontSize?: number;
  highlighted?: boolean;
  lastupdatedBy?: string;
}
