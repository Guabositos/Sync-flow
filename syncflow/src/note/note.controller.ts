import { Controller, Get, Post, Body, Patch, Param, Delete, UseGuards, Query, ForbiddenException } from '@nestjs/common';
import { NoteService } from './note.service';
import { CreateNoteDto } from './dto/create-note.dto';
import { ConnectedUser } from 'src/auth/decorator/user.decorator';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { PaginationDto } from 'src/services/pagination.dto';
import { NoteLineService } from './noteLine.service';
import { CompanyAccessGuard } from 'src/company-access/company-access.guard';
import { Note } from './entities/note.entity';

@Controller('note')
@UseGuards(JwtAuthGuard)
export class NoteController {
  constructor(private readonly noteService: NoteService, private readonly noteLineService: NoteLineService) {}


  @Get('allIds')
  getAllNoteIds(@ConnectedUser() user : JwtPayload, @Body() paginationDto?: PaginationDto) {
    console.log(user);
    return this.noteService.getallIds(user, paginationDto);
  }
  
  @Get("info")
  getNotesInfo(@ConnectedUser() user : JwtPayload, @Body() paginationDto?: PaginationDto) {
    return this.noteService.getNotesInfo(user, paginationDto);
  }

  @UseGuards(CompanyAccessGuard(Note))
  @Get(':id/lines')
  async getNoteLines(
    @Param('id') noteId: string,
    @Query('start') start?: string,
    @Query('limit') limit?: string,
    @ConnectedUser() user?: JwtPayload
  ) {
    const note = await this.noteService.getNoteById(+noteId);
    if (!note) {
      throw new ForbiddenException(`Note with ID ${noteId} not found`);
    }
    return this.noteLineService.getNoteLinesByNoteId(
      +noteId,
      start ? +start : 0,
      limit ? +limit : 100
    );
  }

  @Post()
  create(@ConnectedUser() user: JwtPayload, @Body() createNoteDto: CreateNoteDto) {
    return this.noteService.createNote(createNoteDto, user);
  }

  @UseGuards(CompanyAccessGuard(Note))
  @Post('/:id/create-lines')
  bulkCreate(@ConnectedUser() user: JwtPayload, @Param('id') id: string) {
    
    return this.noteLineService.createMultiple(10, +id);
  }
  

//   @Get()
//   findAll() {
//     return this.noteService.findAll();
//   }

//   @Get(':id')
//   findOne(@Param('id') id: string) {
//     return this.noteService.findOne(+id);
//   }

//   // @Patch(':id')
//   // update(@Param('id') id: string, @Body() updateNoteDto: UpdateNoteDto) {
//   //   return this.noteService.update(+id, updateNoteDto);
//   // }

//   @Delete(':id')
//   remove(@Param('id') id: string) {
//     return this.noteService.remove(+id);
//   }
}
