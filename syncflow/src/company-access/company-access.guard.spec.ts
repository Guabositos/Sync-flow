import { CompanyAccessGuard } from './company-access.guard';

describe('CompanyAccessGuard', () => {
  it('should be defined', () => {
    expect(new CompanyAccessGuard()).toBeDefined();
  });
});
