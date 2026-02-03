import {
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import {
  ObjectLiteral,
  Repository,
  DeepPartial,
  FindOptionsWhere,
} from 'typeorm';
import { PaginationDto } from './pagination.dto';
import { Role } from 'src/enum/role.enum';
import { User } from 'src/user/entities/user.entity';
import { use } from 'passport';
import { CreateEventService } from 'src/history/create-event.service';
import { OperationType } from 'src/enum/operation-type';
import { Note } from 'src/note/entities/note.entity';
import { NoteLine } from 'src/note/entities/noteline.entity';
import { Task } from 'src/task/entities/task.entity';
import { Event } from '../events/entities/event.entity';

@Injectable()
export class SharedService<T extends Note | NoteLine | Task | User | Event> {
  constructor(protected readonly repository: Repository<T>, protected readonly createEventService: CreateEventService) {

  }

  async findAll(filter? : PaginationDto,user?:any): Promise<T[]> {
    try {
      const options: any = {};
      

      if (user?.role !== 'admin') {
        options.where = { user : {id: user?.userId} } as any;
      }
  
      if (filter?.limit !== undefined && filter?.offset !== undefined) {
        options.take = filter.limit;
        options.skip = filter.offset;
      }
  
      return await this.repository.find(options);
    } catch (error) {
      if (error instanceof NotFoundException) {
        throw error;
      }
      throw new InternalServerErrorException(
        'An error occurred while retrieving the entities',
      );
    }
  }

  async findOne(id: number): Promise<T | null > {
    try {
      const where = { id } as unknown as FindOptionsWhere<T>;
      const entity = await this.repository.findOne({ where });
      if (!entity) {
        throw new NotFoundException(`Entity with id ${id} not found`);
      }
      return entity;
    } catch (error) {
      if (error instanceof NotFoundException) {
        throw error;
      }
      throw new InternalServerErrorException(
        `An error occurred while retrieving the entity with id ${id}`,
      );
    }
  }

  async create(data: DeepPartial<T>,userID : number): Promise<T | null> {
    try {
      const entityt = this.repository.create(data);
      const entity =  await this.repository.save(entityt);
      if(!(entity instanceof Note || entity instanceof NoteLine || entity instanceof Task || entity instanceof User || entity instanceof Event)) {
        throw new InternalServerErrorException('Invalid entity type for creation');
      }
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

  async update(id: number, data: DeepPartial<T>, userID?): Promise<T | null> {
  const entity = await this.findOne(id);
  console.log('Entity found for update:', entity);
  if (!entity) {
    throw new NotFoundException(`Entity with id ${id} not found`);
  }

  // Merge only the provided fields into the entity
  console.log('Data to update:', data);
  if (
    !(
      entity instanceof Note ||
      entity instanceof NoteLine ||
      entity instanceof Task ||
      entity instanceof User ||
      entity instanceof Event
    )
  ) {
    throw new InternalServerErrorException('Invalid entity type for update');
  }
  const updated = this.repository.merge(entity, data);
  console.log('Updated entity:', updated);
  const savedEntity = await this.repository.save(updated);

  this.createEventService.createEvent({
    type: OperationType.UPDATE,  
    userId: userID,
    data: savedEntity,
  });

  return savedEntity;
}


  async delete(id: number, userID?): Promise<void> {
    const entity = await this.findOne(id);
    if (!entity) {
      throw new NotFoundException(`Entity with id ${id} not found`);
    }
    const result = await this.repository.softDelete(id);
    if (result.affected === 0) {
      throw new NotFoundException(`Entity with id ${id} not found`);
    }
    this.createEventService.createEvent({
      type: OperationType.DELETE,
      userId: userID,
      data: entity,
    });
  }
}
