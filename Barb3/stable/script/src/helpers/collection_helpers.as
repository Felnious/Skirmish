// Generic collection/dictionary helpers

int DictSize(dictionary@ d)
{
    if (d is null) return 0;
    array<string>@ keys = d.getKeys();
    return (keys is null ? 0 : keys.length());
}
