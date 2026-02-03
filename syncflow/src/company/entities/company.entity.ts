import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, OneToMany, DeleteDateColumn } from 'typeorm';
import { User } from '../../user/entities/user.entity';
import { Note } from '../../note/entities/note.entity';
import { Task } from '../../task/entities/task.entity';
import { Operation } from 'src/history/entities/operation.entity';
import { Event } from '../../events/entities/event.entity';
@Entity()
export class Company {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  code: string; 

  @Column()
  name: string;

  @OneToMany(() => User, user => user.company)
  users: User[];

  @OneToMany(() => Note, note => note.company)
  notes: Note[];

  @OneToMany(() => Task, task => task.company)
  tasks: Task[];

  @OneToMany(() => Event, Event => Event.company)
  events: Event[];

  @OneToMany(() => Operation, operation => operation.company)
  operations: Operation[]; // Assuming Operation has a company relation


  @DeleteDateColumn()
  deletedAt?: Date;

}
