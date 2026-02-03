import { Entity, Column, PrimaryGeneratedColumn, ManyToOne, DeleteDateColumn } from 'typeorm';
import { Company } from '../../company/entities/company.entity';
import { User } from '../../user/entities/user.entity';
import { text } from 'express';
@Entity()
export class Task {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  title: string;

  @Column({ nullable: true, type:"text" })
  description: string;

  @Column({ type: 'timestamp' })
  dueDate: Date;

  @ManyToOne(() => Company, company => company.tasks)
  company: Company;

  @ManyToOne(() => User, user => user.tasks, { nullable: true })
  assignedTo: User;

  @Column({ default: false })
  completed: boolean;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  createdAt: Date;

  @DeleteDateColumn()
  deletedAt?: Date;
}
