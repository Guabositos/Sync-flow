
import { FindOptionsSelect } from 'typeorm';
import { User } from '../entities/user.entity';

export const UserSelectOptions: FindOptionsSelect<User> = {
  id: true,
  username: true,
  role: true,
  company: {
    id: true,
    code: true,
  },
  deletedAt: true,
};