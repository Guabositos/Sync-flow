// Field resolvers for Task type
import { UnauthorizedException } from '@nestjs/common';
export const Task = {

  async assignedTo(parent: any, _args: any, context: any) {
    if (!parent.assignedTo?.id) return null;
    return context.userService.findOne(parent.assignedTo.id);
  },

  async company(parent: any, _args: any, context: any) {
    if (!parent.company?.id) return null;
    return context.companyService.getCompanyById(parent.company.id);
  }
};

// Query resolvers for tasks
export const TaskQuery = {
  async tasks(_parent: any, _args: any, context: any) {
    // Check authentication
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }
    
    return context.taskService.findAll();
  },

  async task(_parent: any, args: { id: string }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    return context.taskService.findOne(parseInt(args.id));
  },

  async tasksByUser(_parent: any, args: { userId: string }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    return context.taskService.getTasksByUser(parseInt(args.userId));
  },

  async tasksByCompany(_parent: any, args: { companyId: number }, context: any) {
    const companyID = context.companyService.findByCode(context.user.companyCode);
    console.log('Fetching tasks for company:', companyID);
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    return context.taskService.getTasksByCompany(args.companyId);
  },
  async tasksbyday(_parent: any, args: { date: string }, context: any) {
    console.log('Context user:', args);
    console.log('Context user:', context.user);
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }
    console.log('Fetching tasks for day:', args.date);
    const date = new Date(args.date);
    return await context.taskService.gettasksbyday(date, context.user.companyCode);
  }
};

// Mutation resolvers for tasks
export const TaskMutation = {
  async createTask(_parent: any, args: { input: any }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    const createTaskDto = {
      title: args.input.title,
      description: args.input.description,
      dueDate: args.input.dueDate,
      completed: args.input.completed ?? false,
      assignedToId: args.input.assignedToId ? parseInt(args.input.assignedToId) : undefined
    };

    return context.taskService.create(createTaskDto, context.user);
  },

  async updateTask(_parent: any, args: { id: string, input: any }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    const updateTaskDto = {
      title: args.input.title,
      description: args.input.description,
      dueDate: args.input.dueDate,
      completed: args.input.completed,
      assignedToId: args.input.assignedToId ? parseInt(args.input.assignedToId) : undefined
    };

    return context.taskService.update(parseInt(args.id), updateTaskDto, context.user);
  },

  async deleteTask(_parent: any, args: { id: string }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    try {
      await context.taskService.remove(parseInt(args.id), context.user);
      return true;
    } catch (error) {
      return false;
    }
  }
};

