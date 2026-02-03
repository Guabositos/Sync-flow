import { Type } from "class-transformer";
import { IsOptional, Min } from "class-validator";

export class CreateNoteDto {
    title: string;
    
    @Type(() => Number)
    @Min(0)
    @IsOptional()
    lineCount: number;
}
