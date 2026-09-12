function clone(value) {
  if (value == null || typeof value !== 'object') return value;
  if (value instanceof Date) return new Date(value.valueOf());
  if (Array.isArray(value)) return value.map(clone);
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, clone(item)])
  );
}

function fakeDb(seed = {}) {
  const store = new Map(Object.entries(seed).map(([path, value]) => [
    path,
    clone(value),
  ]));
  const writes = [];

  function snapshot(path, id) {
    const value = store.get(path);
    return {
      exists: value != null,
      id,
      data: () => clone(value),
    };
  }

  function ref(collection, id) {
    const path = `${collection}/${id}`;
    return {
      id,
      path,
      async get() { return snapshot(path, id); },
    };
  }

  function query(collection, field, value) {
    let maximum = Number.MAX_SAFE_INTEGER;
    const result = {
      limit(count) {
        maximum = count;
        return result;
      },
      async get() {
        const prefix = `${collection}/`;
        const docs = [];
        for (const [path, data] of store.entries()) {
          if (!path.startsWith(prefix) || path.slice(prefix.length).includes('/')) {
            continue;
          }
          if (data?.[field] !== value) continue;
          docs.push(snapshot(path, path.slice(prefix.length)));
          if (docs.length >= maximum) break;
        }
        return {docs};
      },
    };
    return result;
  }

  return {
    store,
    writes,
    db: {
      collection(name) {
        return {
          doc(id) { return ref(name, id); },
          where(field, operator, value) {
            if (operator !== '==') throw new Error('Unsupported fake query');
            return query(name, field, value);
          },
        };
      },
      async runTransaction(fn) {
        const staged = [];
        const transaction = {
          async get(documentRef) {
            return snapshot(documentRef.path, documentRef.id);
          },
          set(documentRef, data) {
            staged.push({path: documentRef.path, data: clone(data)});
          },
        };
        const result = await fn(transaction);
        for (const write of staged) {
          store.set(write.path, clone(write.data));
          writes.push(write);
        }
        return result;
      },
    },
  };
}


module.exports = {clone, fakeDb};
