import { Body, Controller, Delete, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { EventsService } from './events.service';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { ConnectedUser } from 'src/auth/decorator/user.decorator';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';

@Controller('events')
export class EventsController {
  constructor(private readonly service: EventsService) {}
  
  @UseGuards(JwtAuthGuard) 
  @Post()
  create(@ConnectedUser() user:JwtPayload ,@Body() dto: CreateEventDto) {
    dto.createdById = user.sub; 
    return this.service.create(dto, user.sub, user.companyCode);
  }

  @UseGuards(JwtAuthGuard)
  @Get()
  getAllEvents(@ConnectedUser() user: JwtPayload) {
    return this.service.getAll(user.companyCode);
  }

  @UseGuards(JwtAuthGuard)
  @Get('by-month/:date')
  EventByMonth(@Param('date') date: string, @ConnectedUser() user: JwtPayload) {
    const dateObj = new Date(date);
    console.log("ff", this.service.EventByMonth(user.companyCode, dateObj));
    return this.service.EventByMonth(user.companyCode, dateObj);
  }

  @UseGuards(JwtAuthGuard)
  @Get('by-day/:date')
  EventByDay(@Param('date') date: string, @ConnectedUser() user: JwtPayload) {
    const dateObj = new Date(date);
    return this.service.EventByDay(user.companyCode, dateObj);
  }

}
