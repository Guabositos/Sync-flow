// src/events/events.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventsService } from './events.service';
import { EventsController } from './events.controller';
import { Operation } from '../history/entities/operation.entity';
import { UserModule } from '../user/user.module';
import { CreateEventService } from '../history/create-event.service';
import { Event } from './entities/event.entity';
import { Company } from 'src/company/entities/company.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Operation,Event, Company]),
    UserModule
  ],
  controllers: [EventsController],
  providers: [EventsService, CreateEventService],
  exports : [EventsService]
})
export class EventsModule {}
