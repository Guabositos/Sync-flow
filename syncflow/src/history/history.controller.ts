import {
  Controller,
  UseGuards,
  Sse,
  Param,
} from '@nestjs/common';
import { fromEvent, map, Observable } from 'rxjs';
import { EventEmitter2 } from '@nestjs/event-emitter';

import { HistoryService } from './history.service';
import { JwtAuthGuard } from 'src/auth/guards/jwt-auth.guard';
import { RolesGuard } from 'src/auth/role-guard';
import { Roles } from 'src/auth/decorator/roles.decorator';
import { ConnectedUser } from 'src/auth/decorator/user.decorator';
import { JwtPayload } from 'src/auth/jwt-payload.interface';
import { Role } from 'src/enum/role.enum';
import { Operation } from './entities/operation.entity';
import { Target } from 'src/enum/target.enum';
import { get } from 'http';

@Controller('history')
@UseGuards(JwtAuthGuard, RolesGuard)
export class HistoryController {
  constructor(
    private readonly historyService: HistoryService,
    private readonly eventEmitter: EventEmitter2,
  ) {}
  
  @Sse('events')
  @Roles([Role.MANAGER])
  events(@ConnectedUser() user: JwtPayload): Observable<any> {
    const companyCode = user.companyCode;

    console.log(`Subscribing to events for company: ${companyCode}`);

    return fromEvent<Operation>(
      this.eventEmitter,
      `event.created.${companyCode}`,
    ).pipe(
      map((event: Operation) => ({
        data: event,
      }))
    );
  }

  @Sse("targeted-events/:targetType")
  targetedEvents(
    @ConnectedUser() user: JwtPayload,
    @Param('targetType') targetType: Target
  ): Observable<any> {
    const companyCode = user.companyCode;

    console.log(`Subscribing to targeted events for company: ${companyCode}`);

    return fromEvent<Operation>(
      this.eventEmitter,
      `event.created.${companyCode}`,
    ).pipe(
      map((event: Operation) => {
        console.log(`Received event: ${event.targettype}, expected: ${targetType}, ${event.targettype == targetType}`);
        if (event.targettype == targetType) {
          return { data: event };
        }
        return null; 
      }),
      map(event => event ? event : undefined)
    );
  }
}
