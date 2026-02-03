import { Resolver, Query } from '@nestjs/graphql';
import { EventTitleByDateDTO } from '../../events/dto/event-title-by-date.dto';

@Resolver(() => EventTitleByDateDTO)
export class EventResolver {
  constructor() {}
}

export const EventQuery = {
  async getAllEvents(_parent: any, _args: any, context) {
    const code = context.user.companyCode;
  
    const events = await context.eventsService.getAll(code);
    return events;
  },

  async EventByMonth(_parent: any, args: { date: string }, context) {
    const date = new Date(args.date);
    
    const events = await context.eventsService.EventByMonth(context.user.companyCode, date);
    return events;
  },
  async EventByDay(_parent: any, args: { date: string }, context) {
    const companyCode = context.user.companyCode;
    const date = new Date(args.date);
    
    return context.eventsService.EventByDay(context.user.companyCode, date);
}
}