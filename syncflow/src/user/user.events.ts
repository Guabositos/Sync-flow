import { Injectable } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { User } from './entities/user.entity';
import { Subject } from 'rxjs';

@Injectable()
export class UserEvents {
  private userStreams: Map<string, Subject<any>> = new Map();

  getUserStream(userId: string) {
    if (!this.userStreams.has(userId)) {
      this.userStreams.set(userId, new Subject());
    }
    return this.userStreams.get(userId);
  }

  emitToUser(userId: string, event: any) {
    const stream = this.getUserStream(userId);
    if (stream) {
      stream.next(event);
    }
  }

  @OnEvent('user.created')
  handleUserCreated(user: User) {
    if (user.company?.users) {
      user.company.users.forEach(companyUser => {
        this.emitToUser(companyUser.id.toString(), {
          type: 'user.created',
          data: {
            userId: user.id,
            username: user.username,
            message: `New user "${user.username}" has been created!`,
          },
        });
      });
    }
  }

  @OnEvent('user.updated')
  handleUserUpdated(user: User) {
    if (user.company?.users) {
      user.company.users.forEach(companyUser => {
        this.emitToUser(companyUser.id.toString(), {
          type: 'user.updated',
          data: {
            userId: user.id,
            username: user.username,
            message: `User "${user.username}" has been updated!`,
          },
        });
      });
    }
  }

  @OnEvent('user.deleted')
  handleUserDeleted(user: User) {
    if (user.company?.users) {
      user.company.users.forEach(companyUser => {
        this.emitToUser(companyUser.id.toString(), {
          type: 'user.deleted',
          data: {
            userId: user.id,
            username: user.username,
            message: `User "${user.username}" has been deleted!`,
          },
        });
      });
    }
  }

  @OnEvent('user.recovered')
  handleUserRecovered(user: User) {
    if (user.company?.users) {
      user.company.users.forEach(companyUser => {
        this.emitToUser(companyUser.id.toString(), {
          type: 'user.recovered',
          data: {
            userId: user.id,
            username: user.username,
            message: `User "${user.username}" has been recovered!`,
          },
        });
      });
    }
  }
} 