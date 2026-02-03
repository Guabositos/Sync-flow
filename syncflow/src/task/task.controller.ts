import { Controller, Get, Post, Body, Patch, Param, Delete, UseGuards, Sse, Query } from '@nestjs/common';
import { TaskService } from './task.service';
import { CreateTaskDto } from './dto/create-task.dto';
import { UpdateTaskDto } from './dto/update-task.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ConnectedUser } from '../auth/decorator/user.decorator';
import { JwtPayload } from '../auth/jwt-payload.interface';
import { map, Observable, of } from 'rxjs';
import { TaskEvents } from './task.events';
import { PaginationDto } from 'src/services/pagination.dto';
import { Company } from 'src/company/entities/company.entity';
import { CompanyAccessGuard } from 'src/company-access/company-access.guard';
import { Task } from './entities/task.entity';
import { User } from 'src/user/entities/user.entity';

@Controller('tasks')
@UseGuards(JwtAuthGuard)
export class TaskController {
  constructor(
    private readonly taskService: TaskService,
    private readonly taskEvents: TaskEvents
  ) {}

  @Sse('events')
  events(@ConnectedUser() user: JwtPayload): Observable<any> {
      console.log("SSE connected - user.sub:", user.sub); // ← Add this
    if (!user.sub) {
      return of({ type: 'error', data: 'No user ID found' });
    }
    const stream = this.taskEvents.getUserStream(user.sub.toString());
    if (!stream) {
      return of({ type: 'error', data: 'Stream not available' });
    }
    return stream.pipe(map(event => ({
      data: JSON.stringify(event)
    })));
  }
  

  // @Get(':id')
  // findOne(@Param('id') id: string, @ConnectedUser() user: JwtPayload) {
  //   return this.taskService.findOne(+id, user);
  // }
  @UseGuards(CompanyAccessGuard(User))
  @Get('user/:id')
  getTasksByUser(@Param('id') userId: string, @Body() paginationDto?: PaginationDto) {
    return this.taskService.getTasksByUser(+userId, paginationDto);
  }
  @UseGuards(CompanyAccessGuard(Task))
  @Get('user/assigned/:id')
  getAssignedTasksByUser(@Param('id') userId: string, @Body() paginationDto?: PaginationDto) {
    return this.taskService.getAssignedTasksByUser(+userId, paginationDto);
  }
  @UseGuards(CompanyAccessGuard(Task))
  @Get('user/completed/:id')
  getCompletedTasksByUser(@Param('id') userId: string, @Body() paginationDto?: PaginationDto) {
    return this.taskService.getCompletedTasksByUser(+userId, paginationDto);
  }

  @Get('paginated')
  getTasksByCompany(@ConnectedUser() user: JwtPayload, @Body() paginationDto?: PaginationDto) {
    return this.taskService.getPaginatedTasks(user, paginationDto);
  }

  @Get("byMonth/:year/:month")
  getTasksByMonth(@Param('year') year: string, @Param('month') month: string, @ConnectedUser() user: JwtPayload) {
    return this.taskService.gettasksbymonth(+year, +month, user.companyCode);
  }

  @Get('by-day/:date')
  getTasksByDay(@Param('date') date: string, @ConnectedUser() user: JwtPayload) {
    return this.taskService.gettasksbyday(date, user.companyCode);
  }

  @Post()
  create(@Body() createTaskDto: CreateTaskDto, @ConnectedUser() user: JwtPayload) {
    console.log("Creating task for user:", createTaskDto);
    return this.taskService.create(createTaskDto, user);
  }

  @UseGuards(CompanyAccessGuard(Task))
  @Patch(':id')
  update(@Param('id') id: string, @Body() updateTaskDto: UpdateTaskDto, @ConnectedUser() user: JwtPayload) {
    return this.taskService.update(+id, updateTaskDto, user);
  }

  @UseGuards(CompanyAccessGuard(Task))
  @Delete(':id')
  async remove(@Param('id') id: string, @ConnectedUser() user: JwtPayload) {
    await this.taskService.remove(+id, user);
    return { success: true };
  }

  @UseGuards(CompanyAccessGuard(Task))
  @Post("done/:id")
  async markasDone(@Param("id") id : string, @ConnectedUser() user : JwtPayload){
    await this.taskService.markAsDone(id, user);
    return {success : true}
  }
}
