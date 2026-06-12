          int addedCount = 0;
          for (var item in newItems) {
            final shouldSkip = await _db.shouldSkip(item.id);

            if (!shouldSkip) {
              await _db.insertContent(item);
              addedCount++;
            }
          }
