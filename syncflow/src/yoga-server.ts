import { createYoga } from 'graphql-yoga';
import { createSchema } from 'graphql-yoga';
import { Query } from './graphql/resolvers/query';
import { EventQuery } from './graphql/resolvers/event.resolver';

import { INestApplicationContext } from '@nestjs/common';
import { AuthService } from 'src/auth/auth.service'; // ✅ Import AuthService
import { NoteService } from 'src/note/note.service';
import { NoteLineService } from 'src/note/noteLine.service';
import * as fs from 'fs';
import { EventEmitter2 } from '@nestjs/event-emitter';

import * as path from 'path';
import { CompanyService } from './company/company.service';
import { HistoryService } from './history/history.service';
import { UserService } from './user/user.service';
import { ConfigService } from './config/config.service';
import { Operation, NoteLine, Event } from './graphql/resolvers/fieldresolvers';
import { TaskQuery, TaskMutation, Task } from './graphql/resolvers/task.resolvers';
import { UserQuery, UserMutation, UserType } from './graphql/resolvers/user.resolvers';
import { TaskService } from './task/task.service';
import { EventsService } from './events/events.service';
import { JwtService } from '@nestjs/jwt';
import { UnauthorizedException } from '@nestjs/common';

export function createYogaServer(app: INestApplicationContext) {
  const noteService = app.get(NoteService);
  const noteLineService = app.get(NoteLineService);
  const userService = app.get(UserService); 
  const historyService = app.get(HistoryService);
  const companyService = app.get(CompanyService); 
  const configService = app.get(ConfigService);
  const taskService = app.get(TaskService);
  const eventEmitter = app.get(EventEmitter2);
  const jwtService = app.get(JwtService); // ✅ Use Nest's JwtService
  const authService = app.get(AuthService); // ✅ Get AuthService instance

  const accessSecret = configService.getJwtConfig().jwtSecret;

  return createYoga({
    schema: createSchema({
      typeDefs: fs.readFileSync(
        path.join(__dirname, "../src/graphql/schema.graphql"),
        "utf-8"
      ),
      resolvers: {
        Query: {
          ...Query,
          ...TaskQuery,
          ...EventQuery,
          ...UserQuery,
        },
        Mutation: {
          ...TaskMutation,
          ...UserMutation,
        },
        NoteLine,
        Operation,
        Task,
        Event,
        User: UserType,
      }
    }),

    context: async ({ request }) => {
      const authHeader = request.headers.get('authorization');
      const token = authHeader?.replace('Bearer ', '');
      let user: any = null;

      if (token) {
        try {
          const payload = await jwtService.verifyAsync(token, { secret: accessSecret });
          user = {
            userId: payload.sub,
            username: payload.username,
            role: payload.role,
            companyCode: payload.companyCode,
          };
        } catch (e) {
          console.warn('Invalid token:', e.message);
          throw new UnauthorizedException('Invalid token');
        }
      } else {
        console.warn('No token provided');
      }

      return {
        companyCode: user?.companyCode || null,
        user,
        eventsService: app.get(EventsService),
        noteService,
        noteLineService,
        userService,
        historyService,
        companyService,
        taskService,
        eventEmitter
      };
    },
  });
}
