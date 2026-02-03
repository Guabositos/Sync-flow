import { FindOptionsSelect } from 'typeorm';
import { Note } from '../entities/note.entity';

export const NoteSelectOptions: FindOptionsSelect<Note> = {
  id: true,
  title: true,
  company: {
    id: true
  },
  lineCount: true,
}; 