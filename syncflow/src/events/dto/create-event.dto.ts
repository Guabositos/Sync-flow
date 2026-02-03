import { IsNotEmpty } from 'class-validator';
import { Event } from '../entities/event.entity';

export class CreateEventDto implements Partial<Event> {
  @IsNotEmpty()
  title: string;

  @IsNotEmpty()
  description: string;

  @IsNotEmpty()
  date: Date;

  createdById? : number;
}
