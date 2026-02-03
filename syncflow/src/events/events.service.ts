import { Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, DeepPartial, Repository } from 'typeorm';
import { Event  } from './entities/event.entity';
import { CreateEventDto } from './dto/create-event.dto';
import { UpdateEventDto } from './dto/update-event.dto';
import { CreateEventService } from 'src/history/create-event.service';
import { OperationDto } from 'src/history/dto/operation.dto';
import { OperationType } from 'src/enum/operation-type';
import { SharedService } from 'src/services/shared.services';
import { Company } from 'src/company/entities/company.entity';
import { UserService } from 'src/user/user.service';

@Injectable()
export class EventsService{

  constructor(
   @InjectRepository(Event)
    protected readonly repo: Repository<Event>,
    @InjectRepository(Company)
    protected readonly companyRepo: Repository<Company>,
    protected readonly createEventService: CreateEventService,
    protected readonly userServie : UserService
  ) {
  }
    async create(data: CreateEventDto,userID : number, companyCode: string): Promise<Event | null> {
      try {
        const user = await this.userServie.findOne(userID);
        if(!user) {
          throw new NotFoundException(`User with ID ${userID} not found`);
        }
        const company = await this.companyRepo.findOne({
          where: { code: companyCode },
          select: ['id'],
        });
        const new1 = {
          ...data,
          company: company,
          createdBy: user,
        }
        const entityt = this.repo.create(new1 as DeepPartial<Event>);
        const entity =  await this.repo.save(entityt);
        this.createEventService.createEvent({
          type: OperationType.CREATE,
          userId : userID,
          data: entity 
        });
        return entity;
      } catch (error) {
        if (error instanceof NotFoundException) {
          throw error;
        }
        throw new InternalServerErrorException(
          'An error occurred while creating the entity',
        );
      }
    }

  async findByDate(date: Date): Promise<Event[]> {
    // Format date to yyyy-mm-dd for comparison
    const dateStr = date.toDateString().split('T')[0];
    
    return this.repo.createQueryBuilder('event')
      .where('DATE(event.date) = :dateStr', { dateStr })
      .getMany();
  }

  async getAll(companyCode : string, limit: number = 0, offset: number=0) : Promise<any[]> {
    const company = await this.companyRepo.findOne({
      where: { code: companyCode },
      select: ['id'],
    });
    if (!company) {
      throw new NotFoundException(`Company with code ${companyCode} not found`);
    }

    const events = await this.repo.find({
      where: { company: { id: company.id } },
      relations: ['createdBy'],
      select : {id: true, title: true, date: true, description: true, createdBy: { id: true, username: true } },
      order: { date: 'DESC' },
      take: limit > 0 ? limit : undefined,
      skip: offset > 0 ? offset : undefined,
    });

    return events;
  }



  async EventByMonth(companyCode: string, date: Date): Promise<any[]> {
    const company = await this.companyRepo.findOne({
      where: { code: companyCode },
      select: ['id'],
    });
    if (!company) {
      throw new NotFoundException(`Company with code ${companyCode} not found`);
    }

    const startOfMonth = new Date(date.getFullYear(), date.getMonth(), 1);
    const endOfMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0);

    const events = await this.repo.find({
      where: {
        company: { id: company.id },
        date: Between(startOfMonth, endOfMonth),
      },
      relations: ['createdBy'],
      select : {id: true, title: true, date: true, description: true, createdBy: { id: true, username: true } }
    });
    console.log("Events in month:", events);
    return events;
  }
  async EventByDay(companyCode: string, date: Date): Promise<any[]> {
    const startOfDay = new Date(date);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(date);
    endOfDay.setHours(23, 59, 59, 999);

    const company = await this.companyRepo.findOne({
      where: { code: companyCode },
      select: ['id'],
    });
    if (!company) {
      throw new NotFoundException(`Company with code ${companyCode} not found`);
    }

    const events = await this.repo.find({
      where: {
        company: { id: company.id },
        date: Between(startOfDay, endOfDay),
      },
      relations: ['createdBy'],
    });

    return events;
  }

  // async getEventNamesByDate(date: Date): Promise<{ name: string; date: Date }[]> {
  //   const startOfDay = new Date(date);
  //   startOfDay.setHours(0, 0, 0, 0);

  //   const endOfDay = new Date(date);
  //   endOfDay.setHours(23, 59, 59, 999);

  //   const events = await this.repository.find({
  //     where: {
  //       date: Between(startOfDay, endOfDay),
  //     },
  //     select: ['title', 'date'],
  //   });

  //   return events.map(event => ({
  //     name: event.title,
  //     date: event.date,
  //   }));
  // }
}
