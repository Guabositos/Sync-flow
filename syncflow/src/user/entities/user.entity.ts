import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, OneToMany, DeleteDateColumn,  } from 'typeorm';
import { Company } from 'src/company/entities/company.entity';
import { NoteLine } from 'src/note/entities/noteline.entity';
import { Task } from 'src/task/entities/task.entity';
import  {Role} from '../../enum/role.enum';
import { Event } from 'src/events/entities/event.entity';

@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  username: string;

  @Column()
  salt: string;

  @Column()
  password: string;

  @ManyToOne(() => Company, company => company.users)
  company: Company;

  @OneToMany(() => NoteLine, line => line.lastEditedBy)
  editedLines: NoteLine[];

  @OneToMany(() => Task, task => task.assignedTo)
  tasks: Task[];

  @Column({type:'enum', enum: Role, default: Role.USER})
  role: Role;
  
  @DeleteDateColumn()
  deletedAt?: Date;

  @OneToMany(() => Event, event => event.createdBy)
  events: Event[];
 
}
