import 'dart:convert';

import 'package:booksquad/repositories/open_library_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('search prefers the German edition, falls back to the work', () async {
    final repo = OpenLibraryRepository(
      client: MockClient((req) async {
        expect(req.url.queryParameters['lang'], 'de');
        expect(req.url.queryParameters['fields'], contains('editions.title'));
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'docs': [
                {
                  'key': '/works/OL1W',
                  'title': 'The Hobbit',
                  'cover_i': 1,
                  'editions': {
                    'docs': [
                      {
                        'title': 'Der kleine Hobbit',
                        'language': ['ger'],
                        'cover_i': 2,
                      },
                    ],
                  },
                },
                {
                  'key': '/works/OL2W',
                  'title': 'Onyx Storm',
                  'cover_i': 3,
                  'editions': {
                    'docs': [
                      {
                        'title': 'Onyx Storm (US)',
                        'language': ['eng'],
                        'cover_i': 4,
                      },
                    ],
                  },
                },
                {
                  'key': '/works/OL3W',
                  'title': 'Momo',
                  'cover_i': 5,
                  'editions': {
                    'docs': [
                      {
                        'title': ' ',
                        'language': ['ger'],
                      },
                    ],
                  },
                },
                {'key': '/works/OL4W', 'title': 'No editions'},
              ],
            }),
          ),
          200,
        );
      }),
    );
    final books = await repo.search('x');
    expect(books.map((b) => (b.title, b.coverId)), [
      ('Der kleine Hobbit', 2),
      ('Onyx Storm', 3),
      ('Momo', 5),
      ('No editions', null),
    ]);
  });
}
