import 'expense_entities.dart';

abstract class IExpenseRepository {
  Future<void> init();
  Future<List<Person>> getAllPeople();
  Future<void> addPerson(String name);
  Future<void> deletePerson(int id);
  Future<void> addTransaction(Transaction transaction);
  Future<void> dispose();
}
