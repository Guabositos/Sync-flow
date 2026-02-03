import { Injectable } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { Task } from './entities/task.entity';
import { Subject } from 'rxjs';
import { User } from 'src/user/entities/user.entity';

@Injectable()
export class TaskEvents {
  private userStreams: Map<string, Subject<any>> = new Map();

  emitToUser(userId: string, event: any) {
    console.log("emitToUser called with userId:", userId);
    console.log("Available streams:", Array.from(this.userStreams.keys()));

    const stream = this.getUserStream(userId);
    if (stream) {
      console.log("Stream found, emitting event");
      stream.next(event);
    } else {
      console.log("Stream NOT found for userId:", userId);
    }
  }

  getUserStream(userId: string) {
    console.log("getUserStream called for:", userId);
    if (!this.userStreams.has(userId)) {
      console.log("Creating new stream for userId:", userId);
      this.userStreams.set(userId, new Subject());
    }
    return this.userStreams.get(userId);
  }

  @OnEvent('task.completed')
  handleTaskCompleted(task: Task, users: User[]) {
    if (users) {
      users.forEach(user => {
        console.log("emitting to user:", user.id);
        this.emitToUser(user.id.toString(), {
          type: 'task.completed',
          data: {
            taskId: task.id,
            title: task.title,
            message: `Task "${task.title}" has been completed!`,
          },
        });
      });
    }
  }

  @OnEvent('task.dueTomorrow')
  handleTaskDueTomorrow(task: Task) {
    if (task.assignedTo) {
      console.log("lol");
      this.emitToUser(task.assignedTo.id.toString(), {
        type: 'task.dueTomorrow',
        data: {
          taskId: task.id,
          title: task.title,
          message: `Task "${task.title}" is due tomorrow!`,
        },
      });
    }
  }
} 