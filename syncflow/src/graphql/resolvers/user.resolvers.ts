import { Resolver, Query, Mutation, Args, ID } from '@nestjs/graphql';
import { User } from '../../user/entities/user.entity';
import { UserService } from '../../user/user.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { UnauthorizedException } from '@nestjs/common';

@Resolver(() => User)
export class UserResolver {
  constructor(
    private readonly userService: UserService,
    private readonly eventEmitter: EventEmitter2
  ) {}
}

// Field resolvers for User type
export const UserType = {
  async company(parent: any, _args: any, context: any) {
    if (!parent.company?.id) return null;
    return context.companyService.getCompanyById(parent.company.id);
  },

  async editedLines(parent: any, _args: any, context: any) {
    if (!parent.id) return [];
    return context.noteLineService.getLinesByUser(parent.id);
  },

  async tasks(parent: any, _args: any, context: any) {
    if (!parent.id) return [];
    return context.taskService.getTasksByUser(parent.id);
  }
};

// Query resolvers for users
export const UserQuery = {
  async users(_parent: any, _args: any, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }
    
    return context.userService.findAll();
  },

  async user(_parent: any, args: { id: string }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    return context.userService.findOne(parseInt(args.id));
  },

  async userByUsername(_parent: any, args: { username: string, companyId: string }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    return context.userService.findOneByUsername(args.username, parseInt(args.companyId));
  },

  async usersByCompany(_parent: any, args: { companyId: string }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    return context.userService.getUsersByCompany(parseInt(args.companyId));
  },

  async deletedUsers(_parent: any, _args: any, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    return context.userService.findDeleted();
  }
};

// Mutation resolvers for users
export const UserMutation = {
  async updateUser(_parent: any, args: { id: string, input: any }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    const updateUserDto = {
      username: args.input.username,
      password: args.input.password,
      role: args.input.role
    };

    const user = await context.userService.update(parseInt(args.id), updateUserDto, context.user);
    context.eventEmitter.emit('user.updated', user);
    return user;
  },

  async deleteUser(_parent: any, args: { id: string }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    try {
      const user = await context.userService.findOne(parseInt(args.id));
      await context.userService.remove(parseInt(args.id), context.user);
      context.eventEmitter.emit('user.deleted', user);
      return true;
    } catch (error) {
      return false;
    }
  },

  async recoverUser(_parent: any, args: { id: string }, context: any) {
    if (!context.user) {
      throw new UnauthorizedException('Authentification required');
    }

    try {
      const user = await context.userService.recover(parseInt(args.id), context.user);
      context.eventEmitter.emit('user.recovered', user);
      return user;
    } catch (error) {
      throw new Error('Failed to recover user');
    }
  }
}; 