import { Entity, PrimaryGeneratedColumn, Column, ManyToOne, JoinColumn, DeleteDateColumn } from 'typeorm';
import { User } from '../../user/entities/user.entity';
import { Target } from 'src/enum/target.enum';
import { OperationType } from 'src/enum/operation-type';
import { Company } from 'src/company/entities/company.entity';
@Entity()
export class Operation {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({type: 'enum', enum: OperationType})
  type: OperationType;

  @Column()
  date: Date;

  @Column({ type: 'longtext' })
  description: string;
  
  @Column({type:'enum', enum: Target})
  targettype: Target;

  @Column()
  target: number;

  @ManyToOne(() => User)
  @JoinColumn()
  performedBy: User;

  @ManyToOne(() => Company)
  @JoinColumn()
  company: Company;

  @DeleteDateColumn()
  deletedAt?: Date;
}