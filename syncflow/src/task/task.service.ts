import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, MoreThan } from 'typeorm';
import { Task } from './entities/task.entity';
import { CreateTaskDto } from './dto/create-task.dto';
import { UpdateTaskDto } from './dto/update-task.dto';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { isTomorrow } from 'date-fns';
import { JwtPayload } from '../auth/jwt-payload.interface';
import { Company } from '../company/entities/company.entity';
import { User } from '../user/entities/user.entity';
import { SharedService } from '../services/shared.services';
import { CreateEventService } from '../history/create-event.service';
import { TaskSelectOptions } from './dto/task-select.dto';
import { PaginationDto } from 'src/services/pagination.dto';
import { Int } from '@nestjs/graphql';

@Injectable()
export class TaskService {
  private sharedService: SharedService<Task>;

  constructor(
    @InjectRepository(Task)
    private taskRepository: Repository<Task>,
    @InjectRepository(Company)
    private companyRepository: Repository<Company>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private eventEmitter: EventEmitter2,
    private createEventService: CreateEventService,
  ) {
    this.sharedService = new SharedService<Task>(taskRepository, createEventService);
  }

  async create(createTaskDto: CreateTaskDto, user: JwtPayload): Promise<Task> {
    const company = await this.companyRepository.findOne({
      where: { code: user.companyCode }
    });

    if (!company) {
      throw new NotFoundException('Company not found');
    }

    let assignedTo: User | undefined = undefined;
    if (createTaskDto.assignedToId) {
      const foundUser = await this.userRepository.findOne({
        where: { id: createTaskDto.assignedToId, company : { id: company.id } }
      });
      if (!foundUser) {
        throw new NotFoundException('Assigned user not found');
      }
      assignedTo = foundUser;
    }

    const taskData = {
      title: createTaskDto.title,
      description: createTaskDto.description,
      dueDate: createTaskDto.dueDate,
      completed: createTaskDto.completed ?? false,
      company,
      assignedTo
    };

    const temp = await this.sharedService.create(taskData, user.sub, );
    if( !temp ){
      throw new NotFoundException('Failed to create task');
    }
    const savedTask = await this.taskRepository.findOne({
      where: {
        id:temp.id,
      },
      select: TaskSelectOptions,
      relations: ['assignedTo', 'company'],
    });
    
    if (!savedTask) {
      throw new NotFoundException('Failed to create task');
    }
    savedTask.assignedTo ;

    if (isTomorrow(savedTask.dueDate)) {
      this.eventEmitter.emit('task.dueTomorrow', savedTask);
    }
    console.log("Created task:", savedTask);

    return savedTask;
  }

  // async findAll(): Promise<Task[]> {
  //   return this.taskRepository.find({
  //     select: TaskSelectOptions,
  //     relations: ['company', 'assignedTo'],
  //   });
  // }

  async findOne(id: number): Promise<Task> {
    const task = await this.taskRepository.findOne({
      where: { id },
      select: TaskSelectOptions,
      relations: ['assignedTo'],
    });

    if (!task) {
      throw new NotFoundException(`Task with ID ${id} not found`);
    }

    return task;
  }

  async update(id: number, updateTaskDto: UpdateTaskDto, user: JwtPayload): Promise<Task> {
    const task = await this.taskRepository.findOne({
      where: { id, company: { code: user.companyCode } },
      relations: ['assignedTo'],
    });

    // Handle user assignment
    let assignedTo: User | undefined = undefined;
    if (updateTaskDto.assignedToId) {
      const foundUser = await this.userRepository.findOne({
        where: { id: updateTaskDto.assignedToId, company: { code: user.companyCode } }
      });
      if (!foundUser) {
        throw new NotFoundException('Assigned user not found');
      }
      assignedTo = foundUser;
    }

    const updateData = {
      ...updateTaskDto,
      assignedTo
    };

    const updatedTask = await this.sharedService.update(id, updateData, user.sub);
    if (!updatedTask || !updatedTask.id || !updatedTask.dueDate) {
      throw new NotFoundException('Failed to update task');
    }


    if (updateTaskDto.dueDate && isTomorrow(updatedTask.dueDate)) {
      this.eventEmitter.emit('task.dueTomorrow', updatedTask);
    }

    return updatedTask;
  }

  async remove(id: number, user: JwtPayload): Promise<void> {
    await this.sharedService.delete(id, user.sub);
  }

  async getAssignedTasksByUser(userId: number, paginationDto?: PaginationDto): Promise<Task[]> {
    return this.taskRepository.find({
      where: [
      {
        assignedTo: { id: userId },
        completed: false,
      },
      {
        assignedTo: { id: userId },
      },
      
      ],
      select: TaskSelectOptions,
      take: paginationDto?.limit,
      skip: paginationDto?.offset,
      relations: ['company', 'assignedTo'],
    });
  }


  async getCompletedTasksByUser(userId: number, paginationDto?: PaginationDto): Promise<Task[]> {
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

    return this.taskRepository.find({
      where: [
      {
        assignedTo: { id: userId },
        completed: true,
      },
      {
        assignedTo: { id: userId },
        dueDate: MoreThan(oneWeekAgo),
      },
      
      ],
      select: TaskSelectOptions,
      take: paginationDto?.limit,
      skip: paginationDto?.offset,
      relations: ['company', 'assignedTo'],
    });
  }
  async getTasksByUser(userId: number, paginationDto?: PaginationDto): Promise<Task[]> {
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

    return this.taskRepository.find({
      where: [
      {
        assignedTo: { id: userId },
      },
      {
        assignedTo: { id: userId },
        dueDate: MoreThan(oneWeekAgo),
      },
      
      ],
      select: TaskSelectOptions,
      take: paginationDto?.limit,
      skip: paginationDto?.offset,
      relations: ['company', 'assignedTo'],
    });
  }

  // async getTasksByCompany(companyId: number): Promise<Task[]> {
  //   return this.taskRepository.find({
  //     where: { company: { id: companyId } },
  //     select: TaskSelectOptions,
  //     relations: ['company', 'assignedTo'],
  //   });
  // }


  async gettasksbyday(date: string, companyCode: string): Promise<Task[]> {
    const endOfDay = new Date(date);
    endOfDay.setHours(0, 0, 0, 0);
    console.log('End of day:', endOfDay);
    const companyId = await this.companyRepository.findOne({
      where: { code: companyCode },
      select: ['id'],
    });
    if (!companyId) {
      throw new NotFoundException('Company not found');
    }
    return this.taskRepository.find({
      where: {
        company: { id: companyId.id },
        dueDate: endOfDay,
      },
      select: TaskSelectOptions,
      relations: ['company', 'assignedTo'],
    });

  }

  async getPaginatedTasks(user: JwtPayload, paginationDto?: PaginationDto): Promise<Task[]> {
    const company = await this.companyRepository.findOne({
      where: { code: user.companyCode },
      select: ['id'],
    });

    const limit = paginationDto?.limit ? paginationDto.limit : 20;
    const offset = paginationDto?.offset ? paginationDto.offset : 0;
    if (!company) {
      throw new NotFoundException('Company not found');
    }
    console.log("Fetching tasks for company ID:", company.id, "with limit:", limit, "and offset:", offset);
    return this.taskRepository.find({
      where: { company: { id: company.id } },
      take: limit,
      skip: offset,
      select: TaskSelectOptions,
      relations: ['company', 'assignedTo'],
    });
  }

  async gettasksbymonth(year: number, month: number, companyCode: string): Promise<Task[]> {
    const company = await this.companyRepository.findOne({
      where: { code: companyCode },
      select: ['id'],
    });
    if (!company) {
      throw new NotFoundException('Company not found');
    }
    const startDate = new Date(year, month - 1, 1);
    const endDate = new Date(year, month, 0, 23, 59, 59, 999);
    return this.taskRepository.find({
      where: {
        company: { id: company.id },
        dueDate: Between(startDate, endDate),
      },
      select: TaskSelectOptions,
      relations: ['assignedTo'],
    });
  }

  async markAsDone(id:string, user: JwtPayload){
    
    const task = await this.taskRepository.findOne({
      where: { id: parseInt(id), company: { code: user.companyCode } },
      relations: [ 'assignedTo'],
    });
    const users = await this.userRepository.find({
      where: { company: { code: user.companyCode } },
      select: { id : true },
    });

    if (!task || task.completed) {
      throw new NotFoundException('Failed to fetch updated task');
    }
    if(task.assignedTo.id !== user.sub){
      throw new NotFoundException('You are not assigned to this task');
    }
    this.taskRepository.merge(task, { completed: true });
    await this.taskRepository.save(task);
    this.eventEmitter.emit('task.completed', task, users);
  }
}