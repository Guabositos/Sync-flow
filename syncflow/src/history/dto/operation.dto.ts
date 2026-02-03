import { PartialType } from "@nestjs/mapped-types/dist/partial-type.helper";
import { OperationType } from "src/enum/operation-type";
import { Operation } from "../entities/operation.entity";
import { Target } from "src/enum/target.enum";
import { Task } from "src/task/entities/task.entity";
import { Note } from "src/note/entities/note.entity";
import { NoteLine } from "src/note/entities/noteline.entity";
import { User } from "src/user/entities/user.entity";
import { Event } from "src/events/entities/event.entity";

export class OperationDto  extends PartialType(Operation) {
  type: OperationType;
  userId: number;
  data: User | Task |Note | NoteLine| Event;
}