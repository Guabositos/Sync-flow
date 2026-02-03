import { IsDateString } from 'class-validator';

export class EventTitleByDateDTO {
  @IsDateString()
  date: string; // ISO-formatted date string (e.g. "2025-06-01")
}
